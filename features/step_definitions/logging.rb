### logging related step definitions
# for 4.x we default logging installation is via OLM only

### none configurable, just use default parameters
Given /^logging service has been installed successfully$/ do
  ensure_destructive_tagged
  crd_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml"
  step %Q/logging operators are installed with:/, table(%{
    | keep_installation | true        |
  })
  step %Q/I create clusterlogging instance with:/, table(%{
    | remove_logging_pods | false       |
    | crd_yaml            | #{crd_yaml} |
    | log_collector       | fluentd     |
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
Given /^logging operators are installed with:$/ do | table |
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
    namespace_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end
  unless project('openshift-operators-redhat').exists?
    eso_namespace_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/01_eo-project.yaml"
    @result = admin.cli_exec(:create, f: eso_namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end
  logging_ns = "openshift-logging"
  # register clean up if user calls for it.
  if opts[:keep_installation] == 'false'
    teardown_add {
      step %Q/logging service is removed successfully/
    }
  end

  # project('openshift-logging')
  # Create operator group in `openshift-logging` namespace
  opts[:clo_operator_group_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/02_clo_og.yaml"
  @result = admin.cli_exec(:create, f: opts[:clo_operator_group_yaml])
  raise "Error creating operatorgroup" unless @result[:success]

  # Create operator group in `openshift-operators-redhat` namespace
  opts[:eo_operator_group_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/02_eo-og.yaml"
  @result = admin.cli_exec(:create, f: opts[:eo_operator_group_yaml])
  raise "Error creating operatorgroup" unless @result[:success]

  # create RBAC object in `openshift-operators-redhat` namespace
  opts[:operator_group_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/03_eo-rbac.yaml"
  @result = admin.cli_exec(:create, f: opts[:operator_group_yaml])
  raise "Error creating operatorgroup" unless @result[:success]

  step %Q/evaluation of `cluster_version('version').version` is stored in the :ocp_cluster_version clipboard/
  if cb.ocp_cluster_version.include? "4.1."
    # create catalogsourceconfig for cluster-logging-operator and elasticsearch-operator
    opts[:catsrc_logging_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.1/03_clo_csc.yaml"
    opts[:catsrc_elasticsearch_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.1/04_eo-csc.yaml"
    @result = admin.cli_exec(:create, f: opts[:catsrc_logging_yaml])
    raise "Error creating catalogsourceconfig for cluster_logging" unless @result[:success]
    @result = admin.cli_exec(:create, f: opts[:catsrc_elasticsearch_yaml])
    raise "Error creating catalogsourceconfig for elasticsearch" unless @result[:success]

    # create subscription in `openshift-logging` and "openshift-operators-redhat" namespace:
    opts[:sub_logging_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.1/04_clo_sub.yaml"
    opts[:sub_elasticsearch_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.1/05_eo-sub.yaml"
    @result = admin.cli_exec(:create, f: opts[:sub_logging_yaml])
    raise "Error creating subscription for cluster_logging" unless @result[:success]
    @result = admin.cli_exec(:create, f: opts[:sub_elasticsearch_yaml])
    raise "Error creating subscription for elasticsearch" unless @result[:success]

  else
    # create subscription in `openshift-logging` and "openshift-operators-redhat" namespace:
    opts[:sub_logging_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.2/03_clo_sub.yaml"
    opts[:sub_elasticsearch_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.2/04_eo-sub.yaml"
    @result = admin.cli_exec(:create, f: opts[:sub_logging_yaml])
    raise "Error creating subscription for cluster_logging" unless @result[:success]
    @result = admin.cli_exec(:create, f: opts[:sub_elasticsearch_yaml])
    raise "Error creating subscription for elasticsearch" unless @result[:success]
  end

  step %Q/cluster logging operator is ready/
  step %Q/elasticsearch operator is ready/

end

## To check cluserlogging is working correctly, we check all of the subcomponents' status
#  The list of components currently are: ["collection", "curation", "logStore",  "visualization"]
Given /^I wait for clusterlogging(?: named "(.+)")? with #{QUOTED} log collector to be functional in the#{OPT_QUOTED} project$/ do | logging_name, log_collector, proj_name |
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

  # check log collector is ready.
  logger.info("### checking logging subcomponent status: log collector")
  if log_collector == "fluentd" then
    step %Q/a pod becomes ready with labels:/, table(%{
      | component=fluentd |
    })
    fluentd_status = cl.wait_until_fluentd_is_ready
    raise "Failed to wait for fluentd to be ready" unless fluentd_status
  else
    step %Q/a pod becomes ready with labels:/, table(%{
      | component=rsyslog |
    })
    rsyslog_status = cl.wait_until_rsyslog_is_ready
    raise "Failed to wait for rsyslog to be ready" unless rsyslog_status
  end
  # check elasticsearch subcomponent is ready
  logger.info("### checking logging subcomponent status: elasticsearch")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=elasticsearch |
  })
  es_status = cl.wait_until_es_is_ready
  raise "Failed to wait for ES to be ready" unless es_status
  # check curator, which is a cronjob with the name curator

  logger.info("### checking logging subcomponent status: kibana")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=kibana |
  })
  kibana_status = cl.wait_until_kibana_is_ready
  raise "Failed to wait for kibana to be ready" unless kibana_status
  # lastly check the curator cronjob.
  # XXX: the curator pod will not appear immediately after the installation, should we wait for it??
  raise "Failed to find cronjob for curator" if cron_job('curator').schedule.nil?
end

# to cleanup OLM installed clusterlogging
Given /^logging service is removed successfully$/ do
  ensure_destructive_tagged

  # remove namespace
  clo_proj_name = "openshift-logging"
  step %Q/I switch to cluster admin pseudo user/
  if project(clo_proj_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'project', object_name_or_id: clo_proj_name, n: clo_proj_name)
    raise "Unable to delete #{clo_proj_name}" unless @result[:success]
    step %Q/I wait for the resource "project" named "#{clo_proj_name}" to disappear/
  end
  eo_proj_name = "openshift-operators-redhat"
  step %Q/I switch to cluster admin pseudo user/
  if project(eo_proj_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'project', object_name_or_id: eo_proj_name, n: eo_proj_name)
    raise "Unable to delete #{eo_proj_name}" unless @result[:success]
    step %Q/I wait for the resource "project" named "#{eo_proj_name}" to disappear/
  end

  # remove catalogsourceconfigs if ocp cluster version is 4.1
  step %Q/evaluation of `cluster_version('version').version` is stored in the :ocp_cluster_version clipboard/
  if cb.ocp_cluster_version.include? "4.1."
    csc_logging_name = "cluster-logging-operator"
    csc_elasticsearch_name = "elasticsearch"
    @result = admin.cli_exec(:delete, object_type: 'csc', object_name_or_id: csc_logging_name, n: 'openshift-marketplace')
    @result = admin.cli_exec(:delete, object_type: 'csc', object_name_or_id: csc_elasticsearch_name, n: 'openshift-marketplace')
    step %Q/I use the "openshift-marketplace" project/
    step %Q/I wait for the resource "csc" named "#{csc_logging_name}" to disappear/
    step %Q/I wait for the resource "csc" named "#{csc_elasticsearch_name}" to disappear/
  end
end

# For 4.x we just check the clusterlogging status for ES components,
# We have to assume clusterlogging is saved in the cb.cluster_logging
#
Given /^I wait(?: for (\d+) seconds)? until fluentd is ready$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 5 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  fluentd_status = cl.wait_until_fluentd_is_ready(timeout: seconds)
  raise "Failed to wait for fluentd to be ready" unless fluentd_status
end

Given /^I wait(?: for (\d+) seconds)? until rsyslog is ready$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 5 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  rsyslog_status = cl.wait_until_rsyslog_is_ready(timeout: seconds)
  raise "Failed to wait for rsyslog to be ready" unless rsyslog_status
end

Given /^I wait(?: for (\d+) seconds)? until the ES cluster is healthy$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 9 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  es_status = cl.wait_until_es_is_ready(timeout: seconds)
  raise "Failed to wait for ES to be ready" unless es_status
end

Given /^cluster logging operator is ready$/ do
  ensure_admin_tagged
  project("openshift-logging")
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=cluster-logging-operator |
  })
end

Given /^elasticsearch operator is ready$/ do
  ensure_admin_tagged
  project("openshift-operators-redhat")
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=elasticsearch-operator |
  })
end

Given /^I create clusterlogging instance with:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  ensure_admin_tagged
  ensure_destructive_tagged
  log_collector = opts[:log_collector]
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  logging_ns = "openshift-logging"
  opts[:crd_yaml] ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml"
  @result = admin.cli_exec(:create, f: opts[:crd_yaml], n: logging_ns)
  raise "Unable to create clusterlogging instance" unless @result[:success]

  step %Q/I wait for the "instance" clusterloggings to appear/
  step %Q/I wait for the "elasticsearch" elasticsearches to appear/
  step %Q/I wait for the "kibana" deployment to appear/
  step %Q/I wait for the "#{log_collector}" daemonset to appear/
  # to wait for the status informations to show up in the clusterlogging instance
  sleep 10
  step %Q/I wait for clusterlogging with "#{log_collector}" log collector to be functional in the project/
  if opts[:remove_logging_pods] == 'true'
    teardown_add {
      step %Q/I delete the clusterlogging instance with log collector "#{log_collector}"/
    }
  end
end

Given /^I delete the clusterlogging instance with log collector #{QUOTED}/ do | log_collector |
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  logging_ns = "openshift-logging"
  @result = admin.cli_exec(:delete, object_type: 'clusterlogging', object_name_or_id: 'instance', n: logging_ns)
  raise "Unable to delete delete instance" unless @result[:success]
  step %Q/I wait for the resource "deployment" named "kibana" to disappear/
  step %Q/I wait for the resource "elasticsearch" named "elasticsearch" to disappear/
  step %Q/I wait for the resource "cronjob" named "curator" to disappear/
  if log_collector == "fluentd" then
    step %Q/I wait for the resource "daemonset" named "fluentd" to disappear/
  else
    step %Q/I wait for the resource "daemonset" named "rsyslog" to disappear/
  end
end
