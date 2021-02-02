### logging related step definitions
# for 4.x we default logging installation is via OLM only

### none configurable, just use default parameters
Given /^logging service has been installed successfully$/ do
  ensure_destructive_tagged
  ensure_admin_tagged
  if env.version_cmp('4.5', user: user) < 0
    example_cr = "<%= BushSlicer::HOME %>/testdata/logging/clusterlogging/example.yaml"
  else
    example_cr = "<%= BushSlicer::HOME %>/testdata/logging/clusterlogging/example_indexmanagement.yaml"
  end
  step %Q/logging operators are installed successfully/
  step %Q/I create clusterlogging instance with:/, table(%{
    | remove_logging_pods | false         |
    | crd_yaml            | #{example_cr} |
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
    eo_namespace_yaml = "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/01_eo-project.yaml"
    @result = admin.cli_exec(:create, f: eo_namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-operators-redhat" project/
  unless deployment('elasticsearch-operator').exists?
    unless operator_group('openshift-operators-redhat').exists?
      # Create operator group in `openshift-operators-redhat` namespace
      eo_operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/02_eo-og.yaml"
      @result = admin.cli_exec(:create, f: eo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless role_binding('prometheus-k8s').exists?
      # create RBAC object in `openshift-operators-redhat` namespace
      operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/03_eo-rbac.yaml"
      @result = admin.cli_exec(:create, f: operator_group_yaml)
      raise "Error creating rolebinding" unless @result[:success]
    end

    unless subscription('elasticsearch-operator').exists?
      step %Q/I use the "openshift-marketplace" project/
      # first check packagemanifest exists for elasticsearch-operator
      raise "Required packagemanifest 'elasticsearch-operator' no found!" unless package_manifest('elasticsearch-operator').exists?
      step %Q/"elasticsearch-operator" packagemanifest's catalog source name is stored in the :eo_catsrc clipboard/
      step %Q/I use the "openshift-operators-redhat" project/
      if cb.ocp_cluster_version.include? "4.1."
        # create catalogsourceconfig and subscription for elasticsearch-operator
        catsrc_elasticsearch_yaml ||= "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/4.1/04_eo-csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_elasticsearch_yaml)
        raise "Error creating catalogsourceconfig for elasticsearch" unless @result[:success]
        sub_elasticsearch_yaml ||= "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/4.1/05_eo-sub.yaml"
        @result = admin.cli_exec(:create, f: sub_elasticsearch_yaml)
        raise "Error creating subscription for elasticsearch" unless @result[:success]
      else
        # create subscription in "openshift-operators-redhat" namespace:
        sub_elasticsearch_yaml ||= "#{BushSlicer::HOME}/testdata/logging/eleasticsearch/deploy_via_olm/4.2/eo-sub-template.yaml"
        step %Q/I process and create:/, table(%{
          | f | #{sub_elasticsearch_yaml} |
          | p | SOURCE=#{cb.eo_catsrc}    |
          | p | CHANNEL=#{cb.channel}     |
        })
        raise "Error creating subscription for elasticsearch" unless @result[:success]
      end
    end
  end
  # check csv existense
  success = wait_for(300, interval: 10) {
    csv = subscription('elasticsearch-operator').current_csv
    !(csv.nil?) && cluster_service_version(csv).exists?
  }
  raise "CSV #{csv} isn't created" unless success
  step %Q/elasticsearch operator is ready/

  # Create namespace
  unless project('openshift-logging').exists?
    namespace_yaml = "#{BushSlicer::HOME}/testdata/logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-logging" project/
  unless deployment('cluster-logging-operator').exists?
    unless operator_group('openshift-logging').exists?
      clo_operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/logging/clusterlogging/deploy_clo_via_olm/02_clo_og.yaml"
      @result = admin.cli_exec(:create, f: clo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless subscription('cluster-logging').exists?
      step %Q/I use the "openshift-marketplace" project/
      # first check packagemanifest exists for cluster-logging
      raise "Required packagemanifest 'cluster-logging' no found!" unless package_manifest('cluster-logging').exists?
      step %Q/"cluster-logging" packagemanifest's catalog source name is stored in the :clo_catsrc clipboard/
      step %Q/I use the "openshift-logging" project/
      if cb.ocp_cluster_version.include? "4.1."
        # create catalogsourceconfig and subscription for cluster-logging-operator
        catsrc_logging_yaml ||= "#{BushSlicer::HOME}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.1/03_clo_csc.yaml"
        @result = admin.cli_exec(:create, f: catsrc_logging_yaml)
        raise "Error creating catalogsourceconfig for cluster_logging" unless @result[:success]
        sub_logging_yaml ||= "#{BushSlicer::HOME}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.1/04_clo_sub.yaml"
        @result = admin.cli_exec(:create, f: sub_logging_yaml)
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      else
        # create subscription in `openshift-logging` namespace:
        sub_logging_yaml ||= "#{BushSlicer::HOME}/testdata/logging/clusterlogging/deploy_clo_via_olm/4.2/clo-sub-template.yaml"
        step %Q/I process and create:/, table(%{
          | f | #{sub_logging_yaml}     |
          | p | SOURCE=#{cb.clo_catsrc} |
          | p | CHANNEL=#{cb.channel}   |
        })
        raise "Error creating subscription for cluster_logging" unless @result[:success]
      end
    end
  end
  # check csv existense
  success = wait_for(300, interval: 10) {
    csv = subscription('cluster-logging').current_csv
    !(csv.nil?) && cluster_service_version(csv).exists?
  }
  raise "CSV #{csv} isn't created" unless success
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

  # check elasticsearch subcomponent is ready
  logger.info("### checking logging subcomponent status: elasticsearch")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=elasticsearch |
  })
  cl.wait_until_es_is_ready

  # check log collector is ready.
  logger.info("### checking logging subcomponent status: log collector")
  if log_collector == "fluentd" then
    step %Q/a pod becomes ready with labels:/, table(%{
      | component=fluentd |
    })
    cl.wait_until_fluentd_is_ready
  else
    raise "unknow log collector"
  end

  logger.info("### checking logging subcomponent status: kibana")
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=kibana |
  })
  cl.wait_until_kibana_is_ready
  # check the cronjob curator.
  if env.version_lt('4.5', user: user)
    raise "Failed to find cronjob for curator" unless cron_job('curator').exists?
  end

  # check the cronjob index management
  if env.version_gt('4.4', user: user)
    cj_names = ["elasticsearch-im-app", "elasticsearch-im-audit", "elasticsearch-im-infra"]
    for cj_name in cj_names do
      raise "Failed to find cronjob for #{cj_name}" unless cron_job(cj_name).exists?
    end
  end
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

Given /^I wait until #{QUOTED} log collector is ready$/ do | log_collector |
  step %Q/#{daemon_set(log_collector).replica_counters[:desired]} pods become ready with labels:/, table(%{
    | logging-infra=#{log_collector} |
  })
end

Given /^I wait until ES cluster is ready$/ do
  step %Q/#{cluster_logging('instance').logstore_node_count.to_i} pods become ready with labels:/, table(%{
    | cluster-name=elasticsearch,component=elasticsearch |
  })
  cluster_logging('instance').wait_until_es_is_ready
end

Given /^I wait until kibana is ready$/ do
  step %Q/#{deployment('kibana').replica_counters[:desired]} pods become ready with labels:/, table(%{
    | component=kibana |
  })
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
  if opts[:check_status].nil?
    check_status = 'true'
  else
    check_status = opts[:check_status]
  end

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
  step %Q/I wait for the "instance" clusterloggings to appear up to 300 seconds/
  if check_status == 'true'
    step %Q/I wait for the "elasticsearch" elasticsearches to appear up to 300 seconds/
    step %Q/I wait for the "kibana" deployment to appear up to 300 seconds/
    log_collector = cluster_logging('instance').collection_type
    step %Q/I wait for the "#{log_collector}" daemonset to appear up to 300 seconds/
    # to wait for the status informations to show up in the clusterlogging instance
    #sleep 10
    #step %Q/I wait for clusterlogging with "#{log_collector}" log collector to be functional in the project/
    step %Q/I wait until ES cluster is ready/
    step %Q/I wait until "#{log_collector}" log collector is ready/
    step %Q/I wait until kibana is ready/
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
  step %Q/I wait for the resource "daemonset" named "fluentd" to disappear/
  step %Q/all existing pods die with labels:/, table(%{
    | component=elasticsearch |
  })
  step %Q/all existing pods die with labels:/, table(%{
    | component=kibana |
  })
end

Given /^logging channel name is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  cb_name = 'logging_channel_name' unless cb_name
  if env.logging_channel_name.empty?
    version = cluster_version('version').version.split('-')[0].split('.').take(2).join('.')
    case version
    when '4.1'
      cb[cb_name] = "preview"
    when '4.7'
      cb[cb_name] = "5.0"
    else
      cb[cb_name] = version
    end
  else
    cb[cb_name] = env.logging_channel_name
  end
end

Given /^#{QUOTED} packagemanifest's catalog source name is stored in the#{OPT_SYM} clipboard$/ do |packagemanifest, cb_name|
  cb_name = "catsrc_name" unless cb_name
  project("openshift-marketplace")
  if env.logging_catsrc.empty?
    if catalog_source("qe-app-registry").exists?
      cb[cb_name] = "qe-app-registry"
    else
      @result = admin.cli_exec(:get, resource: 'packagemanifest', resource_name: packagemanifest, n: 'openshift-marketplace', o: 'yaml')
      raise "Unable to get catalog source name" unless @result[:success]
      cb[cb_name] = @result[:parsed]['status']['catalogSource']
    end
  else
    cb[cb_name] = env.logging_catsrc
  end
end

Given /^the logging operators are redeployed after scenario$/ do
  _admin = admin
  teardown_add {
    step %Q/logging operators are installed successfully/
  }
end

# from logging 4.5, we don't have index project.$project-name.xxxxx, so we need other ways to check the project logs
# es_util --query=*/_count -d '{"query": {"match": {"kubernetes.namespace_name": "project-name"}}}'
# if count > 0, then the project logs are received
When /^I wait(?: (\d+) seconds)? for the project #{QUOTED} logs to appear in the ES pod(?: with labels #{QUOTED})?$/ do |seconds, project_name, pod_labels|
  if pod_labels
    labels = pod_labels
  else
    labels = "es-node-master=true"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | #{labels} |
  })

  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 10 * 60
  success = wait_for(seconds) {
    step %Q/I perform the HTTP request on the ES pod with labels "#{labels}":/, table(%{
      | relative_url | */_count?format=JSON' -d '{"query": {"match": {"kubernetes.namespace_name": "#{project_name}"}}} |
      | op           | GET                                                                                              |
    })
    res = @result[:parsed]
    if res
      res['count'] > 0
    end
  }
  cb.doc_count = @result[:parsed]['count']
  raise "Can't find logs from project '#{project_name}' in #{seconds} seconds" unless success
end

Given /^logging eventrouter is installed in the cluster$/ do
  step %Q/admin ensures "event-reader" cluster_role is deleted after scenario/
  step %Q/admin ensures "event-reader-binding" cluster_role_binding is deleted after scenario/
  step %Q/admin ensures "eventrouter" service_account is deleted from the "openshift-logging" project after scenario/
  step %Q/admin ensures "eventrouter" config_map is deleted from the "openshift-logging" project after scenario/
  step %Q/admin ensures "eventrouter" deployment is deleted from the "openshift-logging" project after scenario/
  clo_csv_version = subscription("cluster-logging").current_csv(cached: false)
  if clo_csv_version.include? "cluster-logging"
    image_version = clo_csv_version.match(/cluster-logging\.(.*)/)[1].split('-')[0]
  else
    image_version = clo_csv_version.match(/clusterlogging\.(.*)/)[1].split('-')[0]
  end
  if image_version.start_with?("5")
    # from logging 5.0, the image name is changed to eventrouter-rhel8
    image_name = "eventrouter-rhel8"
  else
    image_name = "logging-eventrouter"
  end

  if image_content_source_policy('brew-registry').exists?
    registry = image_content_source_policy('brew-registry').mirror_repository[0]
    if image_version.start_with?("5")
      # from logging 5.0, the image namespace is changed to openshift-logging
      image = "#{registry}/rh-osbs/openshift-logging-#{image_name}:v#{image_version}"
    else
      image = "#{registry}/rh-osbs/openshift-ose-#{image_name}:v#{image_version}"
    end
  else
    # get image registry from CLO
    clo_image = deployment('cluster-logging-operator').container_spec(name: 'cluster-logging-operator').image
    registry = clo_image.split(/cluster-logging(.*)/)[0]
    image = "#{registry}#{image_name}:v#{image_version}"
  end
  step %Q/I process and create:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/eventrouter/internal_eventrouter.yaml |
    | p | IMAGE=#{image} |
  })
  step %Q/the step should succeed/
  step %Q/a pod becomes ready with labels:/, table(%{
    | component=eventrouter |
  })
end

Given /^I generate certs for the#{OPT_QUOTED} receiver(?: in the#{OPT_QUOTED} project)?$/ do | receiver_name, project_name |
  script_file = "#{BushSlicer::HOME}/testdata/logging/logforwarding/cert_generation.sh"
  project_name ||= "openshift-logging"
  #step %Q/I download a file from "#{script_file}"/
  shell_cmd = "sh #{script_file} $(pwd) #{project_name} #{receiver_name}"
  system(shell_cmd)
end

Given /^I create pipelinesecret(?: named#{OPT_QUOTED})? with auth type (mTLS|mTLS_share|server_auth|server_auth_share)$/ do | secret_name, auth_type |
  secret_name ||= "pipelinesecret"
  unless tagged_upgrade?
    step %Q/admin ensures "#{secret_name}" secret is deleted from the "openshift-logging" project after scenario/
  end
  case auth_type
  when "mTLS"
    step %Q/I run the :create_secret admin command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | tls.key=logging-es.key   |
      | from_file    | tls.crt=logging-es.crt   |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | n            | openshift-logging        |
    })
  when "mTLS_share"
    step %Q/I run the :create_secret admin command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | tls.key=logging-es.key   |
      | from_file    | tls.crt=logging-es.crt   |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | from_literal | shared_key=fluentdserver |
      | n            | openshift-logging        |
    })
  when "server_auth"
    step %Q/I run the :create_secret admin command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | n            | openshift-logging        |
    })
  when "server_auth_share"
    step %Q/I run the :create_secret admin command with:/, table(%{
      | name         | #{secret_name}           |
      | secret_type  | generic                  |
      | from_file    | ca-bundle.crt=ca.crt     |
      | from_file    | ca.key=ca.key            |
      | from_literal | shared_key=fluentdserver |
      | n            | openshift-logging        |
    })
  else
    raise "Unrecognized auth type: #{auth_type}"
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

  unless tagged_upgrade?
    step %Q/I ensure "#{receiver_name}" service_account is deleted from the "#{namespace}" project after scenario/
  end
  @result = user.cli_exec(:create_serviceaccount, serviceaccount_name: receiver_name, n: namespace)
  raise "Unable to create serviceaccout #{receiver_name}" unless @result[:success]

  if tagged_upgrade?
    step %Q/SCC "privileged" is added to the "system:serviceaccount:<%= project.name %>:#{receiver_name}" service account without teardown/
  else
    step %Q/SCC "privileged" is added to the "system:serviceaccount:<%= project.name %>:#{receiver_name}" service account/
    step %Q/I ensure "#{receiver_name}" config_map is deleted from the "#{namespace}" project after scenario/
    step %Q/I ensure "#{receiver_name}" deployment is deleted from the "#{namespace}" project after scenario/
    step %Q/I ensure "#{receiver_name}" service is deleted from the "#{namespace}" project after scenario/
  end

  files = [configmap_file, deployment_file]
  for file in files do
    @result = user.cli_exec(:create, f: file, n: namespace)
    raise "Unable to create resoure with #{file}" unless @result[:success]
  end
  if receiver_name == "rsyslogserver"
    svc_file = "#{BushSlicer::HOME}/testdata/logging/logforwarding/rsyslog/rsyslogserver_svc.yaml"
    @result = user.cli_exec(:create, f: svc_file, n: namespace)
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

Given /^(fluentd|elasticsearch|rsyslog) receiver is deployed as (secure|insecure)(?: with (mTLS|mTLS_share|server_auth|server_auth_share) enabled)?(?: in the#{OPT_QUOTED} project)?$/ do | server, security, auth_type, project_name |
  project_name ||= "openshift-logging"
  project(project_name)
  if env.version_lt('4.6', user: user)
    file_dir = "#{BushSlicer::HOME}/testdata/logging/logforwarding"
  else
    file_dir = "#{BushSlicer::HOME}/testdata/logging/clusterlogforwarder"
  end
  case server
  when "fluentd"
    receiver_name = "fluentdserver"
    pod_label = "logging-infra=fluentdserver"
    if security == "secure"
      step %Q/I generate certs for the "fluentdserver" receiver in the "<%= project.name %>" project/
      unless tagged_upgrade?
        step %Q/I ensure "fluentdserver" secret is deleted from the "<%= project.name %>" project after scenario/
      end
      # create secret/fluentdserver for fluentd server pod
      step %Q/I run the :create_secret client command with:/, table(%{
        | name         | fluentdserver            |
        | secret_type  | generic                  |
        | from_file    | tls.key=logging-es.key   |
        | from_file    | tls.crt=logging-es.crt   |
        | from_file    | ca-bundle.crt=ca.crt     |
        | from_file    | ca.key=ca.key            |
        | from_literal | shared_key=fluentdserver |
        | n            | #{project_name}          |
      })
      step %Q/the step should succeed/
      # set configmap and create pipeline secret in openshift-logging project
      case auth_type
      when "mTLS_share"
        configmap_file = "#{file_dir}/fluentd/secure/cm-mtls-share.yaml"
      when "mTLS"
        configmap_file = "#{file_dir}/fluentd/secure/cm-mtls.yaml"
      when "server_auth"
        configmap_file = "#{file_dir}/fluentd/secure/cm-serverauth.yaml"
      when "server_auth_share"
        configmap_file = "#{file_dir}/fluentd/secure/cm-serverauth-share.yaml"
      else
        raise "Unrecognized auth type: #{auth_type}"
      end
      step %Q/I create pipelinesecret with auth type #{auth_type}/
      deployment_file = "#{file_dir}/fluentd/secure/deployment.yaml"
    else
      configmap_file = "#{file_dir}/fluentd/insecure/configmap.yaml"
      deployment_file = "#{file_dir}/fluentd/insecure/deployment.yaml"
    end

  when "elasticsearch"
    receiver_name = "elasticsearch-server"
    pod_label = "app=elasticsearch-server"
    if security == "secure"
      step %Q/I generate certs for the "elasticsearch-server" receiver in the "<%= project.name %>" project/
      unless tagged_upgrade?
        step %Q/I ensure "elasticsearch-server" secret is deleted from the "<%= project.name %>" project after scenario/
      end
      step %Q/I run the :create_secret client command with:/, table(%{
        | name        | elasticsearch-server                |
        | secret_type | generic                             |
        | from_file   | logging-es.key=logging-es.key       |
        | from_file   | logging-es.crt=logging-es.crt       |
        | from_file   | elasticsearch.key=elasticsearch.key |
        | from_file   | elasticsearch.crt=elasticsearch.crt |
        | from_file   | admin-ca=ca.crt                     |
        | n           | #{project_name}                     |
      })
      step %Q/the step should succeed/
      # create pipeline secret for fluentd
      step %Q/I create pipelinesecret with auth type mTLS/
      configmap_file = "#{file_dir}/elasticsearch/secure/configmap.yaml"
      deployment_file = "#{file_dir}/elasticsearch/secure/deployment.yaml"
    else
      configmap_file = "#{file_dir}/elasticsearch/insecure/configmap.yaml"
      deployment_file = "#{file_dir}/elasticsearch/insecure/deployment.yaml"
    end

  when "rsyslog"
    receiver_name = "rsyslogserver"
    pod_label = "component=rsyslogserver"
    configmap_file = "#{file_dir}/rsyslog/insecure/rsyslogserver_configmap.yaml"
    deployment_file = "#{file_dir}/rsyslog/insecure/rsyslogserver_deployment.yaml"
  else
    raise "Unrecognized server: #{server}"
  end

  step %Q/I create the resources for the receiver with:/, table(%{
    | namespace       | #{project_name}    |
    | receiver_name   | #{receiver_name}   |
    | configmap_file  | #{configmap_file}  |
    | deployment_file | #{deployment_file} |
    | pod_label       | #{pod_label}       |
  })
end

# upgrade operator and check the EFK pods status
Given /^I upgrade the operator with:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  subscription = opts[:subscription]
  channel = opts[:channel]
  catsrc = opts[:catsrc]
  namespace = opts[:namespace]
  project(namespace)

  # upgrade operator
  patch_json = {"spec": {"channel": "#{channel}", "source": "#{catsrc}"}}
  patch_opts = {resource: "subscription", resource_name: subscription, p: patch_json.to_json, n: namespace, type: "merge"}
  @result = admin.cli_exec(:patch, **patch_opts)
  raise "Patch failed with #{@result[:response]}" unless @result[:success]
  # wait till new csv to be installed
  success = wait_for(180, interval: 10) {
    subscription(subscription).installplan_csv.include? cb.channel
  }
  raise "the new CSV can't be installed" unless success
  # wait till new csv is ready
  success = wait_for(600, interval: 10) {
    new_csv = subscription(subscription).current_csv(cached: false)
    cluster_service_version(new_csv).ready?[:success]
  }
  raise "can't upgrade operator #{subscription}" unless success

  #check if the EFK pods could be upgraded successfully
  project("openshift-logging")
  if cluster_logging('instance').log_store_spec != nil
    if elasticsearch('elasticsearch').exists?
      if subscription == "elasticsearch-operator"
        # check if the ES cluster could be upgraded
        success = wait_for(300, interval: 10) {
          elasticsearch('elasticsearch').nodes_status[0]["upgradeStatus"]["scheduledUpgrade"]
        }
        raise "Can't upgrade the ES cluster" unless success
      end
      # wait for the ES cluster to be ready
      success = wait_for(600, interval: 10) {
        elasticsearch('elasticsearch').cluster_health == "green" &&
        (elasticsearch('elasticsearch').nodes_status.last["upgradeStatus"].empty? ||
        elasticsearch('elasticsearch').nodes_status.last["upgradeStatus"]["scheduledUpgrade"].nil?)
      }
      raise "ES cluster isn't in a good status" unless success
      # check pvc count
      unless BushSlicer::PersistentVolumeClaim.list(user: user, project: project).count == cluster_logging('instance').logstore_node_count
        raise "The PVC count doesn't match the ES node count"
      end
    else
      raise "The elasticsearch/elasticsearch is not created"
    end
  end

  # check the kibana status
  if cluster_logging('instance').visualization_spec != nil
    if deployment('kibana').exists?
      success = wait_for(300, interval: 10) {
        (deployment('kibana').replica_counters(cached: false)[:desired] == deployment('kibana').replica_counters(cached: false)[:updated]) &&
        (deployment('kibana').replica_counters(cached: false)[:desired] == deployment('kibana').replica_counters(cached: false)[:available])
      }
      raise "Kibana isn't in a good status" unless success
    else
      raise "Deployment/kibana does not exist"
    end
  end

  # check fluentd status
  if cluster_logging('instance').collection_spec != nil
    if daemon_set('fluentd').exists?
      success = wait_for(300, interval: 10) {
        (daemon_set('fluentd').replica_counters(cached: false)[:desired] == daemon_set('fluentd').replica_counters(cached: false)[:updated_scheduled]) &&
        (daemon_set('fluentd').replica_counters(cached: false)[:desired] == daemon_set('fluentd').replica_counters(cached: false)[:available])
      }
      raise "Fluentd isn't in a good status" unless success
    else
      raise "Daemonset/fluentd doesn't exist"
    end
  end
end

# only check the major version, such as 4.4, 4.5, 4.6, don't care about versions like 4.6.0-2020xxxxxxxx
Given /^I make sure the logging operators match the cluster version$/ do
  step %Q/I switch to cluster admin pseudo user/
  # check if channel name in subscription is same to the target channel
  step %Q/logging channel name is stored in the :channel clipboard/
  #cv = cluster_version('version').version.split('-')[0].split('.').take(2).join('.')
  # check EO
  project("openshift-operators-redhat")
  eo_current_channel = subscription("elasticsearch-operator").channel(cached: false)
  #eo_csv_version = subscription("elasticsearch-operator").current_csv(cached: false).match(/elasticsearch-operator\.(.*)/)[1].split('-')[0].split('.').take(2).join('.')
  if cb.channel != eo_current_channel
  #if eo_csv_version != cv
    upgrade_eo = true
    step %Q/"elasticsearch-operator" packagemanifest's catalog source name is stored in the :catsrc clipboard/
    step %Q/I upgrade the operator with:/, table(%{
      | namespace    | openshift-operators-redhat |
      | subscription | elasticsearch-operator     |
      | channel      | #{cb.channel}              |
      | catsrc       | #{cb.catsrc}               |
    })
    step %Q/the step should succeed/
  else
    upgrade_eo = false
  end
  # check CLO
  project("openshift-logging")
  clo_current_channel = subscription("cluster-logging").channel(cached: false)
  #clo_csv_version = subscription("cluster-logging").current_csv(cached: false).match(/clusterlogging\.(.*)/)[1].split('-')[0].split('.').take(2).join('.')
  if clo_current_channel != cb.channel
  #if clo_csv_version != cv
    upgrade_clo = true
    step %Q/"cluster-logging" packagemanifest's catalog source name is stored in the :catsrc clipboard/
    step %Q/I upgrade the operator with:/, table(%{
      | namespace    | openshift-logging |
      | subscription | cluster-logging   |
      | channel      | #{cb.channel}     |
      | catsrc       | #{cb.catsrc}      |
    })
    step %Q/the step should succeed/
  else
    upgrade_clo = false
  end
  # check cronjobs if the CLO or/and EO is upgraded
  project("openshift-logging")
  if (upgrade_eo || upgrade_clo) && (BushSlicer::CronJob.list(user: user, project: project).count != 0)
    step %Q/I check the cronjob status/
    step %Q/the step should succeed/
  end
end

# check cronjob status
# delete all the jobs, and wait up to 15min to check the jobs status
Given /^I check the cronjob status$/ do
  # check logging version
  project("openshift-operators-redhat")
  eo_version = subscription("elasticsearch-operator").current_csv(cached: false)[23..-1].split('-')[0]
  project("openshift-logging")
  clo_version = subscription("cluster-logging").current_csv(cached: false)[16..-1].split('-')[0]
  #csv version >= 4.5, check rollover/delete cronjobs, csv < 4.5, only check curator cronjob
  if ["4.0", "4.1", "4.2", "4.3", "4.4"].include? clo_version.split('.').take(2).join('.')
    if cron_job('curator').exists?
      # remove all the old jobs
      @result = admin.cli_exec(:delete, object_type: 'job', l: 'component=curator', n: 'openshift-logging')
      # wait up to 6 minutes for the cronjob to be recreated
      success = wait_for(360, interval: 10) {
        BushSlicer::Job.list(user: user, project: project).count >= 1
      }
      raise "can't recreate cronjobs" unless success
    else
      raise "cronjob curator doesn't exist"
    end
  else
    cj_names = ["elasticsearch-im-app", "elasticsearch-im-audit", "elasticsearch-im-infra"]
    for cj_name in cj_names do
      raise "cronjob #{cj_name} doesn't exist" unless cron_job(cj_name).exists?
    end
    # remove all the old jobs
    @result = admin.cli_exec(:delete, object_type: 'job', l: 'component=indexManagement', n: 'openshift-logging')
    # wait up to 16 minutes for the cronjob to be recreated
    success = wait_for(960, interval: 10) {
      BushSlicer::Job.list(user: user, project: project).count >= 3
    }
    raise "can't recreate cronjobs" unless success
  end

  # check the new jobs could be successfully
  # wait up to 1 minute for the jobs to complete
  jobs = BushSlicer::Job.list(user: user, project: project)
  job_names = jobs.map(&:name)
  for job_name in job_names
    success = wait_for(60, interval: 5) {
      job(job_name).succeeded == 1
    }
    raise "#{job_name} failed to complete" unless success
  end
end

# This step will deploy one kafka cluster and create 4 topics(topic-logging-all,topic-logging-infra,topic-logging-app,topic-logging-audit) in this kafka
Given /^I deploy kafka in the #{QUOTED} project via amqstream operator$/ do | project_name|
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/"amq-streams" packagemanifest's catalog source name is stored in the :kafka_csc clipboard/

  step %Q/I use the "#{project_name}" project/
  step %Q/I process and create:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/02_og_amqstreams_template.yaml |
    | p | AMQ_NAMESPACE=#{project_name} |
  })
  raise "Error create operatorgroup" unless @result[:success]

  step %Q/I process and create:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/03_sub_amqstreams_template.yaml |
    | p | AMQ_NAMESPACE=#{project_name}  |
    | p | AMQ_CATALOGSOURCE=#{cb.kafka_csc} |
  })
  raise "Error subscript amqstreams" unless @result[:success]

  step %Q/a pod becomes ready with labels:/, table(%{
    | name=amq-streams-cluster-operator |
  })

  step %Q/I process and create:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/04_kafka_my-cluster_amqstreams_template.yaml |
    | p | AMQ_NAMESPACE=#{project_name} |
  })
  raise "Error create kafka" unless @result[:success]

  @result = admin.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/05_kafkatopics_amqstreams.yaml")
  raise "Error create kafka topics" unless @result[:success]

  step %Q/3 pods becomes ready with labels:/, table(%{
    | strimzi.io/name=my-cluster-kafka |
  })
  raise "Error kafka cluster not ready" unless @result[:success]
end

# Get some records from a kafka topic
# https://datacadamia.com/dit/kafka/kafka-console-consumer
Given /^I get(?: (\d+))? records from the #{QUOTED} kafka topic in the #{QUOTED} project$/ do | record_num, topic_name, project_name|
  record_num = record_num ? record_num.to_str : "10"
  job_name=rand_str(8, :dns)
  step %Q/I use the "#{project_name}" project/
  kafka_image=stateful_set('my-cluster-kafka').containers_spec(user: user)[0].image
  teardown_add {
    admin.cli_exec(:delete, object_type: 'job', object_name_or_id: job_name, n: project_name)
  }
  step %Q/I process and create:/,table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/21_job_topic_consumer_from_beginning_template.yaml |
    | p | KAFKA_IMAGE=#{kafka_image} |
    | p | KAFKA_TOPIC=#{topic_name}  |
    | p | MAX_MESSAGES=#{record_num} |
    | p | JOB_NAME=#{job_name} |
  })
  step %Q/a pod becomes ready with labels:/, table(%{
    | job-name=#{job_name}|
  })

  # wait up to 1 minutes for the kafka message
  success = wait_for(60, interval: 15) {
    @result = user.cli_exec(:logs, {resource_name: "#{pod.name}"})
    @result[:response].match("pipeline_metadata")
  }
  raise "Couldn't received logs from the kafka topic #{topic_name}" unless success
end

# Register an topic consumer which listen the topic continuously. we can verify the logging records by the next step 'I get N logs from the X kafka consumer job'
Given /^I create the #{QUOTED} consumer job to the #{QUOTED} kafka topic in the #{QUOTED} project$/ do | job_name, topic_name, project_name |
  step %Q/I use the "#{project_name}" project/
  kafka_image=stateful_set('my-cluster-kafka').containers_spec(user: user)[0].image
  teardown_add {
    admin.cli_exec(:delete, object_type: 'job', object_name_or_id: job_name, n: project_name)
  }
  step %Q/I process and create:/,table(%{
    | f | #{BushSlicer::HOME}/testdata/logging/clusterlogforwarder/kafka/amq/21_job_topic_consumer_from_latest_template.yaml |
    | p | KAFKA_IMAGE=#{kafka_image} |
    | p | KAFKA_TOPIC=#{topic_name} |
    | p | JOB_NAME=#{job_name} |
  })
  raise "Unable to create consumer job" unless @result[:success]
end

# Get logs from the kafka comsumer job which created by upper job
Given /^I get(?: (\d+))? logs from the #{QUOTED} kafka consumer job in the #{QUOTED} project$/ do | record_num, job_name, project_name |
  record_num = record_num ? record_num.to_i : 0
  step %Q/I use the "#{project_name}" project/
  step %Q/a pod becomes ready with labels:/, table(%{
    | job-name=#{job_name}|
  })

  # wait up to 1 minutes for the kafka message
  success = wait_for(60, interval: 10) {
    if record_num >0
      @result = user.cli_exec(:logs, {resource_name: "#{pod.name}", tail: "#{ record_num }"})
    else
      @result = user.cli_exec(:logs, {resource_name: "#{pod.name}"})
    end
    @result[:response].match("pipeline_metadata")
  }
  raise "Couldn't retrieve kafka records #{pod.name}" unless success
end
