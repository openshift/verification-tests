### logging related step definitions
# for 4.x we default logging installation is via OLM only

### none configurable, just use default parameters
Given /^logging service has been installed successfully$/ do
  ensure_destructive_tagged
  ensure_admin_tagged
  crd_yaml = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/example.yaml"
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
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/evaluation of `cluster_version('version').version` is stored in the :ocp_cluster_version clipboard/
  step %Q/logging channel name is stored in the :channel clipboard/

  unless project('openshift-operators-redhat').exists?
    eo_namespace_yaml = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/01_eo-project.yaml"
    @result = admin.cli_exec(:create, f: eo_namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-operators-redhat" project/
  unless deployment('elasticsearch-operator').exists?
    unless operator_group('openshift-operators-redhat').exists?
      # Create operator group in `openshift-operators-redhat` namespace
      eo_operator_group_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/02_eo-og.yaml"
      @result = admin.cli_exec(:create, f: eo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless role_binding('prometheus-k8s').exists?
      # create RBAC object in `openshift-operators-redhat` namespace
      operator_group_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/03_eo-rbac.yaml"
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
        catsrc_elasticsearch_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/4.1/04_eo-csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_elasticsearch_yaml)
        raise "Error creating catalogsourceconfig for elasticsearch" unless @result[:success]
        sub_elasticsearch_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/4.1/05_eo-sub.yaml"
        @result = admin.cli_exec(:create, f: sub_elasticsearch_yaml)
        raise "Error creating subscription for elasticsearch" unless @result[:success]
      else
        # create subscription in "openshift-operators-redhat" namespace:
        sub_elasticsearch_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eleasticsearch/deploy_via_olm/4.2/eo-sub-template.yaml"
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
    namespace_yaml = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-logging" project/
  unless deployment('cluster-logging-operator').exists?
    unless operator_group('openshift-logging').exists?
      clo_operator_group_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/deploy_clo_via_olm/02_clo_og.yaml"
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
        catsrc_logging_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.1/03_clo_csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_logging_yaml)
        raise "Error creating catalogsourceconfig for cluster_logging" unless @result[:success]
        sub_logging_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.1/04_clo_sub.yaml"
        @result = admin.cli_exec(:create, f: sub_logging_yaml)
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      else
        # create subscription in `openshift-logging` namespace:
        sub_logging_yaml ||= "#{ENV['BUSHSLICER_HOME']}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.2/clo-sub-template.yaml"
        step %Q/I process and create:/, table(%{
          | f | #{sub_logging_yaml}    |
          | p | SOURCE=#{cb.clo_opsrc} |
          | p | CHANNEL=#{cb.channel}  |
        })
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      end
    end
  end

  step %Q/elasticsearch operator is ready/
  step %Q/cluster logging operator is ready/
end

## To check cluserlogging is working correctly, we check all of the subcomponents' status
#  The list of components currently are: ["collection", "curation", "logStore",  "visualization"]
Given /^I wait for clusterlogging(?: named "(.+)")? with #{QUOTED} log collector to be functional in the#{OPT_QUOTED} project$/ do | logging_name, log_collector, proj_name |
  ensure_admin_tagged
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
  ensure_admin_tagged
  # remove namespace
  clo_proj_name = "openshift-logging"
  step %Q/I switch to cluster admin pseudo user/
  if project(clo_proj_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'project', object_name_or_id: clo_proj_name, n: clo_proj_name)
    raise "Unable to delete #{clo_proj_name}" unless @result[:success]
    step %Q/I wait for the resource "project" named "#{clo_proj_name}" to disappear/
  end
  eo_proj_name = "openshift-operators-redhat"
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

Given /^elasticsearch operator is ready(?: in the "(.+)" namespace)?$/ do | proj_name |
  ensure_admin_tagged
  if proj_name
    target_namespace = proj_name
  else
    target_namespace = "openshift-operators-redhat"
  end
  project(target_namespace)
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=elasticsearch-operator |
  })
end

Given /^I create clusterlogging instance with:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  logging_ns = "openshift-logging"
  crd_yaml = opts[:crd_yaml]

  if cluster_logging("instance").exists?
    step %Q/I delete the clusterlogging instance/
  end

  @result = admin.cli_exec(:create, f: crd_yaml, n: logging_ns)
  raise "Unable to create clusterlogging instance" unless @result[:success]
  if opts[:remove_logging_pods] == 'true'
    teardown_add {
      step %Q/I delete the clusterlogging instance/
    }
  end
  log_collector = opts[:log_collector]
  step %Q/I wait for the "instance" clusterloggings to appear up to 300 seconds/
  step %Q/I wait for the "elasticsearch" elasticsearches to appear up to 300 seconds/
  step %Q/I wait for the "kibana" deployment to appear up to 300 seconds/
  step %Q/I wait for the "#{log_collector}" daemonset to appear up to 300 seconds/
  # to wait for the status informations to show up in the clusterlogging instance
  sleep 10
  step %Q/I wait for clusterlogging with "#{log_collector}" log collector to be functional in the project/
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

Given /^logging channel name is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  cb_name = 'logging_channel_name' unless cb_name
  if cluster_version('version').version.include?('4.1.')
    cb[cb_name] = "preview"
  else
    cb[cb_name] = cluster_version('version').channel.split('-')[1]
  end
end

Given /^#{QUOTED} packagemanifest's operator source name is stored in the#{OPT_SYM} clipboard$/ do |packagemanifest, cb_name|
  cb_name = "opsrc_name" unless cb_name
  project("openshift-marketplace")
  if catalog_source("qe-app-registry").exists?
    cb[cb_name] = "qe-app-registry"
  else
    @result = admin.cli_exec(:get, resource: 'packagemanifest', resource_name: packagemanifest, n: 'openshift-marketplace', o: 'yaml')
    raise "Unable to get opsrc name" unless @result[:success]
    cb[cb_name] = @result[:parsed]['status']['catalogSource']
  end
end

Given /^the logging operators are redeployed after scenario$/ do
  _admin = admin
  teardown_add {
    step %Q/logging operators are installed successfully/
  }
end

Given /^logging eventrouter is installed in the cluster$/ do
  step %Q/admin ensures "event-reader" cluster_role is deleted after scenario/
  step %Q/admin ensures "event-reader-binding" cluster_role_binding is deleted after scenario/
  step %Q/admin ensures "eventrouter" service_account is deleted from the "openshift-logging" project after scenario/
  step %Q/admin ensures "eventrouter" config_map is deleted from the "openshift-logging" project after scenario/
  step %Q/admin ensures "eventrouter" deployment is deleted from the "openshift-logging" project after scenario/
  @result = admin.cli_exec(:new_app, file: "#{ENV['BUSHSLICER_HOME']}/testdata/logging/eventrouter/internal_eventrouter.yaml")
  unless @result[:success]
    raise "Unable to deploy eventrouter"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=eventrouter |
  })
end

Given /^I generate certs for the#{OPT_QUOTED} receiver(?: in the#{OPT_QUOTED} project)?$/ do | receiver_name, project_name |
  script_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/cert_generation.sh"
  project_name ||= "openshift-logging"
  step %Q/I download a file from "#{script_file}"/
  shell_cmd = "sh cert_generation.sh $(pwd) #{project_name} #{receiver_name}"
  system(shell_cmd)
end

Given /^I create pipelinesecret(?: named#{OPT_QUOTED})?(?: with sharedkey#{OPT_QUOTED})?$/ do | secret_name, shared_key |
  secret_name ||= "pipelinesecret"
  step %Q/admin ensures "#{secret_name}" secret is deleted from the "openshift-logging" project after scenario/
  if shared_key != nil
    step %Q/I run the :create_secret client command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | tls.key=logging-es.key   |
      | from_file    | tls.crt=logging-es.crt   |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | from_literal | shared_key=#{shared_key} |
      | n            | openshift-logging        |
    })
  else
    step %Q/I run the :create_secret client command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | tls.key=logging-es.key   |
      | from_file    | tls.crt=logging-es.crt   |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | n            | openshift-logging        |
    })
  end
  step %Q/the step should succeed/
end

Given /^I create the resources for the receiver with:$/ do | table |
  org_user = user
  opts = opts_array_to_hash(table.raw)
  namespace = opts[:namespace]
  receiver_name = opts[:receiver_name]
  configmap_file = opts[:configmap_file]
  deployment_file = opts[:deployment_file]
  pod_label = opts[:pod_label]
  project(namespace)

  step %Q/I ensures "#{receiver_name}" service_account is deleted from the "#{namespace}" project after scenario/
  @result = user.cli_exec(:create_serviceaccount, serviceaccount_name: receiver_name, n: namespace)
  raise "Unable to create serviceaccout #{receiver_name}" unless @result[:success]
  step %Q/SCC "privileged" is added to the "system:serviceaccount:<%= project.name %>:#{receiver_name}" service account/

  step %Q/I ensures "#{receiver_name}" config_map is deleted from the "#{namespace}" project after scenario/
  step %Q/I ensures "#{receiver_name}" deployment is deleted from the "#{namespace}" project after scenario/
  step %Q/I ensures "#{receiver_name}" service is deleted from the "#{namespace}" project after scenario/
  files = [configmap_file, deployment_file]
  for file in files do
    @result = user.cli_exec(:create, f: file)
    raise "Unable to create resoure with #{file}" unless @result[:success]
  end
  if receiver_name == "rsyslogserver"
    svc_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/rsyslog/rsyslogserver_svc.yaml"
    @result = user.cli_exec(:create, f: svc_file)
    raise "Unable to expose the service for rsyslog server" unless @result[:success]
  else
    @result = user.cli_exec(:expose, name: receiver_name, resource: 'deployment', resource_name: receiver_name, namespace: namespace)
    raise "Unable to expose the service for #{receiver_name}" unless @result[:success]
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | #{pod_label} |
  })
  step %Q/evaluation of `pod` is stored in the :log_receiver clipboard/
end

Given /^(fluentd|elasticsearch|rsyslog) receiver is deployed as (secure|insecure)(?: in the#{OPT_QUOTED} project)?$/ do | server, security, project_name |
  project_name ||= "openshift-logging"
  org_user = user
  project(project_name)
  case server
  when "fluentd"
    receiver_name = "fluentdserver"
    pod_label = "logging-infra=fluentdserver"
    if security == "secure"
      step %Q/I generate certs for the "fluentdserver" receiver in the "<%= project.name %>" project/
      step %Q/I ensures "fluentdserver" secret is deleted from the "<%= project.name %>" project after scenario/
      step %Q/I run the :create_secret client command with:/, table(%{
        | name         | fluentdserver            |
        | secret_type  | generic                  |
        | from_file    | tls.key=logging-es.key   |
        | from_file    | tls.crt=logging-es.crt   |
        | from_file    | ca-bundle.crt=ca.crt     |
        | from_file    | ca.key=ca.key            |
        | from_literal | shared_key=fluentdserver |
      })
      step %Q/the step should succeed/
      if project_name != "openshift-logging"
        step %Q/I create pipelinesecret named "fluentdserver" with sharedkey "fluentdserver"/
      end
      configmap_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/fluentd/secure/configmap.yaml"
      deployment_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/fluentd/secure/fluentdserver_deployment.yaml"
    else
      configmap_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/fluentd/insecure/configmap.yaml"
      deployment_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/fluentd/insecure/fluentdserver_deployment.yaml"
    end

  when "elasticsearch"
    receiver_name = "elasticsearch-server"
    pod_label = "app=elasticsearch-server"
    if security == "secure"
      step %Q/I generate certs for the "elasticsearch-server" receiver in the "<%= project.name %>" project/
      step %Q/I ensures "elasticsearch-server" secret is deleted from the "<%= project.name %>" project after scenario/
      step %Q/I run the :create_secret client command with:/, table(%{
        | name        | elasticsearch-server                |
        | secret_type | generic                             |
        | from_file   | logging-es.key=logging-es.key       |
        | from_file   | logging-es.crt=logging-es.crt       |
        | from_file   | elasticsearch.key=elasticsearch.key |
        | from_file   | elasticsearch.crt=elasticsearch.crt |
        | from_file   | admin-ca=ca.crt                     |
      })
      step %Q/the step should succeed/
      step %Q/I create pipelinesecret named "piplinesecret"/
      configmap_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/elasticsearch/secure/configmap.yaml"
      deployment_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/elasticsearch/secure/deployment.yaml"
    else
      configmap_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/elasticsearch/insecure/configmap.yaml"
      deployment_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/elasticsearch/insecure/deployment.yaml"
    end

  when "rsyslog"
    receiver_name = "rsyslogserver"
    pod_label = "component=rsyslogserver"
    configmap_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/rsyslog/insecure/rsyslogserver_configmap.yaml"
    deployment_file = "#{ENV['BUSHSLICER_HOME']}/testdata/logging/logforwarding/rsyslog/insecure/rsyslogserver_deployment.yaml"

  end

  step %Q/I create the resources for the receiver with:/, table(%{
    | namespace       | #{project_name}    |
    | receiver_name   | #{receiver_name}   |
    | configmap_file  | #{configmap_file}  |
    | deployment_file | #{deployment_file} |
    | pod_label       | #{pod_label}       |
  })
end
