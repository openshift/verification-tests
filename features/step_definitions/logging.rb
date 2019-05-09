### logging related step definitions
# for 4.x we default logging installation is via OLM only

### none configurable, just use default parameters
Given /^logging service has been installed successfully$/ do
  ensure_destructive_tagged
  crd_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml"
  step %Q/logging service is installed with:/, table(%{
    | keep_installation | true        |
    | crd_yaml          | #{crd_yaml} |
  })
end

### configurable installation of logging
# available parameters are:
# :keep_installation: true/false   -- keep installation if true
# :crd_yaml  -- http url for logging crd yaml
# operator_group_yaml -- http url for operator group yaml
# :catsrc_logging_yaml] -- http url for catalogsourceconfig for logging
# :catsrc_elasticsearch_yaml] -- http url for catalogsourceconfig for ES
# :sub_logging_yaml  -- http url for logging subscription yaml
# :sub_elasticsearch_yaml -- http url for elastic search yaml
#
Given /^logging service is installed with:$/ do | table |
  ensure_destructive_tagged
  opts = opts_array_to_hash(table.raw)
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-marketplace" project/
  # first check packagemanifest exists for cluster-logging and elasticsearch-operator
  required_packagemanifests = ['cluster-logging', 'elasticsearch-operator']
  required_packagemanifests.each do |pm_name|
    raise "Required packagemanifest #{pm_name} no found!" unless package_manifest(pm_name).exists?
  end
  # Create namespace
  unless project('openshift-logging').exists?
    # oc create -f https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/namespace.yaml
    namespace_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/namespace.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end
  logging_ns = "openshift-logging"
  # register clean up if user calls for it.
  unless opts[:keep_installation]
    teardown_add {
      step %Q/logging service is removed successfully/
    }
  end

  # project('openshift-logging')
  # Create operator group in `openshift-logging` namespace
  opts[:operator_group_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/operator-group.yaml"
  @result = admin.cli_exec(:create, f: opts[:operator_group_yaml], n: logging_ns)
  raise "Error creating operatorgroup" unless @result[:success]
  # create catalogsourceconfig for logging and elasticsearch
  opts[:catsrc_logging_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/csc-clusterlogigng.yaml"
  opts[:catsrc_elasticsearch_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/csc-elasticsearch.yaml"

  @result = admin.cli_exec(:create, f: opts[:catsrc_logging_yaml])
  raise "Error creating catalogsourceconfig for cluster_logging" unless @result[:success]
  @result = admin.cli_exec(:create, f: opts[:catsrc_elasticsearch_yaml])
  raise "Error creating catalogsourceconfig for elasticsearch" unless @result[:success]

  # create subscription in "openshift-operators" namespace:
  opts[:sub_logging_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/sub-cluster-logging.yaml"
  opts[:sub_elasticsearch_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/OCP-21311/sub-elasticsearch-operator.yaml"

  @result = admin.cli_exec(:create, f: opts[:sub_logging_yaml])
  raise "Error creating subscription for cluster_logging" unless @result[:success]
  @result = admin.cli_exec(:create, f: opts[:sub_elasticsearch_yaml])
  raise "Error creating subscription for elasticsearch" unless @result[:success]
  step %Q/cluster logging operator is ready/
  # create instance in openshift-logging namespace
  opts[:crd_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml"
  @result = admin.cli_exec(:create, f: opts[:crd_yaml], n: logging_ns)
  # Check the resource created by OLM
  step %Q/I wait for clusterlogging to be functional in the project/
end

## To check cluserlogging is working correctly, we check all of the subcomponents' status
#  The list of components currently are: ["collection", "curation", "logStore",  "visualization"]
Given /^I wait for clusterlogging(?: named "(.+)")? to be functional in the#{OPT_QUOTED} project$/ do | logging_name,  proj_name |
  ensure_destructive_tagged
  cb.target_proj ||= 'openshift-logging'
  proj_name = cb.target_proj if proj_name.nil?
  org_proj_name = project.name
  logging_name ||= 'instance'
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "#{proj_name}" project/

  cb.cluster_logging ||= cluster_logging(logging_name)
  cl = cb.cluster_logging
  logger.info("### checking logging subcomponent status")
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=cluster-logging-operator |
  })

  # check fluentd is ready, but first make sure fluentd pods are there.
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=fluentd |
  })
  cl.wait_until_fluentd_is_ready
  # check elasticsearch subcomponent is ready
  cl.wait_until_es_is_ready
  # check curator, which is a cronjob with the name curator
  cl.wait_until_kibana_is_ready
  # lastly check the curator cronjob.
  # XXX: the curator pod will not appear immediately after the installation, should we wait for it??
  raise "Failed to find cronjob for curator" if cron_job('curator').schedule.nil?
end

# to cleanup OLM installed clusterlogging
# 1. remove namespace
Given /^logging service is removed successfully$/ do
  ensure_destructive_tagged

  proj_name = "openshift-logging"
  step %Q/I switch to cluster admin pseudo user/
  # 1. remove namespace
  if project(proj_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'project', object_name_or_id: proj_name, n: proj_name)
    raise "Unable to delete #{proj_name}" unless @result[:success]
    step %Q/I wait for the resource "project" named "#{proj_name}" to disappear/
  end
  # remove elastic subscription
  @result = admin.cli_exec(:delete, object_type: 'sub', object_name_or_id: 'elasticsearch-operator', n: 'openshift-operators')

  step %Q/I use the "openshift-operators" project/
  step %Q/I wait for the resource "sub" named "elasticsearch-operator" to disappear/
  @result = admin.cli_exec(:delete, object_type: 'csc', object_name_or_id: 'cluster-logging-operator', n: 'openshift-marketplace')
  @result = admin.cli_exec(:delete, object_type: 'csc', object_name_or_id: 'elasticsearch-operator', n: 'openshift-marketplace')
  step %Q/I use the "openshift-marketplace" project/
  step %Q/I wait for the resource "csc" named "cluster-logging-operator" to disappear/
  step %Q/I wait for the resource "csc" named "elasticsearch-operator" to disappear/

end

# For 4.x we just check the clusterlogging status for ES components,
# We have to assume clusterlogging is saved in the cb.cluster_logging
#
Given /^I wait(?: for (\d+) seconds)? until fluentd is ready$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 5 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  cl.wait_until_fluentd_is_ready(timeout: seconds)
end

Given /^I wait(?: for (\d+) seconds)? until the ES cluster is healthy$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 9 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  cl.wait_until_es_is_ready(timeout: seconds)
end

Given /^cluster logging operator is ready$/ do
  ensure_admin_tagged
  project("openshift-logging")

  step %Q/a pod becomes ready with labels:/, table(%{
    | name=cluster-logging-operator |
  })

end
