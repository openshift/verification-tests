### logging related step definitions
# for 4.x we default logging installation is via OLM only

### none configurable, just use default parameters
Given /^logging service has been installed successfully$/ do
  ensure_destructive_tagged
  crd_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml"
  step %Q/logging operators are installed successfully/
  step %Q/I create clusterlogging instance with:/, table(%{
    | remove_logging_pods | true        |
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
Given /^logging operators are installed successfully$/ do
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/evaluation of `cluster_version('version').version` is stored in the :ocp_cluster_version clipboard/
  step %Q/logging channel name is stored in the :channel clipboard/

  unless project('openshift-operators-redhat').exists?
    eo_namespace_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/01_eo-project.yaml"
    @result = admin.cli_exec(:create, f: eo_namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-operators-redhat" project/
  unless deployment('elasticsearch-operator').exists?
    unless operator_group('openshift-operators-redhat').exists?
      # Create operator group in `openshift-operators-redhat` namespace
      eo_operator_group_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/02_eo-og.yaml"
      @result = admin.cli_exec(:create, f: eo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless role_binding('prometheus-k8s').exists?
      # create RBAC object in `openshift-operators-redhat` namespace
      operator_group_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/03_eo-rbac.yaml"
      @result = admin.cli_exec(:create, f: operator_group_yaml)
      raise "Error creating rolebinding" unless @result[:success]
    end

    unless subscription('elasticsearch-operator').exists?
      step %Q/I use the "openshift-marketplace" project/
      # first check packagemanifest exists for elasticsearch-operator
      raise "Required packagemanifest 'elasticsearch-operator' no found!" unless package_manifest('elasticsearch-operator').exists?
      step %Q/"elasticsearch-operator" packagemanifest's operator source name is stored in the :eo_opsrc clipboard/
      step %Q/I use the "openshift-operators-redhat" project/
      if cb.ocp_cluster_version.include? "4.1."
        # create catalogsourceconfig and subscription for elasticsearch-operator
        catsrc_elasticsearch_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.1/04_eo-csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_elasticsearch_yaml)
        raise "Error creating catalogsourceconfig for elasticsearch" unless @result[:success]
        sub_elasticsearch_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.1/05_eo-sub.yaml"
        @result = admin.cli_exec(:create, f: sub_elasticsearch_yaml)
        raise "Error creating subscription for elasticsearch" unless @result[:success]
      else
        # create subscription in "openshift-operators-redhat" namespace:
        sub_elasticsearch_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/eleasticsearch/deploy_via_olm/4.2/eo-sub-template.yaml"
        step %Q/I process and create:/, table(%{
          | f | #{sub_elasticsearch_yaml} |
          | p | SOURCE=#{cb.eo_opsrc}     |
          | p | CHANNEL=#{cb.channel}     |
        })
        raise "Error creating subscription for elasticsearch" unless @result[:success]
      end
    end
  end

  # Create namespace
  unless project('openshift-logging').exists?
    namespace_yaml = "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-logging" project/
  unless deployment('cluster-logging-operator').exists?
    unless operator_group('openshift-logging').exists?
      clo_operator_group_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/02_clo_og.yaml"
      @result = admin.cli_exec(:create, f: clo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless subscription('cluster-logging').exists?
      step %Q/I use the "openshift-marketplace" project/
      # first check packagemanifest exists for cluster-logging
      raise "Required packagemanifest 'cluster-logging' no found!" unless package_manifest('cluster-logging').exists?
      step %Q/"cluster-logging" packagemanifest's operator source name is stored in the :clo_opsrc clipboard/
      step %Q/I use the "openshift-logging" project/
      if cb.ocp_cluster_version.include? "4.1."
        # create catalogsourceconfig and subscription for cluster-logging-operator
        catsrc_logging_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.1/03_clo_csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_logging_yaml)
        raise "Error creating catalogsourceconfig for cluster_logging" unless @result[:success]
        sub_logging_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.1/04_clo_sub.yaml"
        @result = admin.cli_exec(:create, f: sub_logging_yaml)
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      else
        # create subscription in `openshift-logging` namespace:
        sub_logging_yaml ||= "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/deploy_clo_via_olm/4.2/clo-sub-template.yaml"
        step %Q/I process and create:/, table(%{
          | f | #{sub_logging_yaml}    |
          | p | SOURCE=#{cb.clo_opsrc} |
          | p | CHANNEL=#{cb.channel}  |
        })
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      end
    end
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
  log_collector ||= 'fluentd'

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
    cl.wait_until_fluentd_is_ready
  else
    step %Q/a pod becomes ready with labels:/, table(%{
      | component=rsyslog |
    })
    cl.wait_until_rsyslog_is_ready
  end
  # check elasticsearch subcomponent is ready
  logger.info("### checking logging subcomponent status: elasticsearch")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=elasticsearch |
  })
  cl.wait_until_es_is_ready
  # check curator, which is a cronjob with the name curator

  logger.info("### checking logging subcomponent status: kibana")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=kibana |
  })
  cl.wait_until_kibana_is_ready
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
  cl.wait_until_fluentd_is_ready(timeout: seconds)
end

Given /^I wait(?: for (\d+) seconds)? until rsyslog is ready$/ do |seconds|
  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 5 * 60
  cb.cluster_logging ||= cluster_logging('instance')
  cl = cb.cluster_logging
  cl.wait_until_rsyslog_is_ready(timeout: seconds)
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
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  logging_ns = "openshift-logging"
  crd_yaml = opts[:crd_yaml]

  if cluster_logging("instance").exists?
    step %Q/I delete the clusterlogging instance/
  end

  @result = admin.cli_exec(:create, f: crd_yaml, n: logging_ns)
  raise "Unable to create clusterlogging instance" unless @result[:success]
  log_collector = opts[:log_collector]
  step %Q/I wait for the "instance" clusterloggings to appear/
  step %Q/I wait for the "elasticsearch" elasticsearches to appear/
  step %Q/I wait for the "kibana" deployment to appear/
  step %Q/I wait for the "#{log_collector}" daemonset to appear/
  # to wait for the status informations to show up in the clusterlogging instance
  sleep 10
  step %Q/I wait for clusterlogging with "#{log_collector}" log collector to be functional in the project/

  if opts[:remove_logging_pods] == 'true'
    teardown_add {
      step %Q/I delete the clusterlogging instance/
    }
  end
end

Given /^I delete the clusterlogging instance$/ do
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  logging_ns = "openshift-logging"
  if cluster_logging("instance").exists?
    @result = admin.cli_exec(:delete, object_type: 'clusterlogging', object_name_or_id: 'instance', n: logging_ns)
    raise "Unable to delete instance" unless @result[:success]
  end
  step %Q/I wait for the resource "deployment" named "kibana" to disappear/
  step %Q/I wait for the resource "elasticsearch" named "elasticsearch" to disappear/
  step %Q/I wait for the resource "cronjob" named "curator" to disappear/
  step %Q/I wait for the resource "daemonset" named "rsyslog" to disappear/
  step %Q/I wait for the resource "daemonset" named "fluentd" to disappear/
end

Given /^I run curl command on the CLO pod to get metrics with:$/ do | table |
  ensure_admin_tagged
  opts = opts_array_to_hash(table.raw)
  step %Q/a pod becomes ready with labels:/, table(%{
      | name=cluster-logging-operator |
    })
  query_object = opts[:object]
  query_opts = "-H \"Authorization: Bearer #{opts[:token]}\" -H \"Content-type: application/json\""
  case query_object
  when "rsyslog", "fluentd"
    query_cmd = "curl -k #{query_opts} https://#{opts[:service_ip]}:24231/metrics"
  when "elasticsearch"
    query_cmd = "curl -k #{query_opts} https://#{opts[:service_ip]}:60000/_prometheus/metrics"
  else
    raise "Invalid query_object"
  end

  @result = pod.exec("bash", "-c", query_cmd, as: admin, container: "cluster-logging-operator")
  if @result[:success]
    @result[:parsed] = YAML.load(@result[:response])
    if @result[:parsed].is_a? Hash and @result[:parsed].has_key? 'status'
      @result[:exitstatus] = @result[:parsed]['status']
    end
  else
    raise "Get metrics failed with error, #{@result[:response]}"
  end
end

Given /^logging channel name is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  cb_name = 'logging_channel_name' unless cb_name
  case
  when cluster_version('version').version.include?('4.1.')
    cb[cb_name] = "preview"
  when cluster_version('version').version.include?('4.2.')
    cb[cb_name] = "4.2"
  when cluster_version('version').version.include?('4.3.')
    cb[cb_name] = "4.3"
  end
end

Given /^#{QUOTED} packagemanifest's operator source name is stored in the#{OPT_SYM} clipboard$/ do |packagemanifest, cb_name|
  cb_name = "opsrc_name" unless cb_name
  @result = admin.cli_exec(:get, resource: 'packagemanifest', resource_name: packagemanifest, n: 'openshift-marketplace', o: 'yaml')
  raise "Unable to get opsrc name" unless @result[:success]
  cb[cb_name] = @result[:parsed]['metadata']['labels']['opsrc-owner-name']
end
