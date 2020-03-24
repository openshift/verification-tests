# helper step for logging and metrics scenarios
require 'oga'
require 'parseconfig'
require 'stringio'
require 'promethues_metrics_data'

# since the logging and metrics module can be deployed and used in any namespace, this step is used to determine
# under what namespace the logging/metrics module is deployed under by getting all of the projects as admin and
And /^I save the (logging|metrics) project name to the#{OPT_SYM} clipboard$/ do |svc_type, clipboard_name|
  ensure_destructive_tagged

  if clipboard_name.nil?
    cb_name = svc_type
  else
    cb_name = clipboard_name
  end
  if svc_type == 'logging'
    expected_rc_name = "logging-kibana-1"
  else
    expected_rc_name = "hawkular-metrics"
  end
  found_proj = BushSlicer::Project.get_matching(user: admin) { |project, project_hash|
    rc(expected_rc_name, project).exists?(user: admin, quiet: true)
  }
  if found_proj.count != 1
    raise ("Found #{found_proj.count} #{svc_type} services installed in the cluster, expected 1")
  else
    cb[cb_name] = found_proj[0].name
  end
end

Given /^there should be (\d+) (logging|metrics) services? installed/ do |count, svc_type|
  ensure_destructive_tagged

  if svc_type == 'logging'
    expected_rc_name = "logging-kibana-1"
  else
    expected_rc_name = "hawkular-metrics"
  end

  found_proj = BushSlicer::Project.get_matching(user: admin) { |project, project_hash|
    rc(expected_rc_name, project).exists?(user: admin, quiet: true)
  }
  if found_proj.count != Integer(count)
    raise ("Found #{found_proj.count} #{svc_type} services installed in the cluster, expected #{count}")
  end
end

# short-hand for the generic uninstall step if we are just using the generic install
Given /^I remove (logging|metrics|metering) service using ansible$/ do | svc_type |
  if cb.install_prometheus
    uninstall_inventory = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_inventory_uninstall_prometheus"
  else
    uninstall_inventory = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/generic_uninstall_inventory"
  end
  step %Q/#{svc_type} service is uninstalled with ansible using:/, table(%{
    | inventory     | #{uninstall_inventory}          |
    | playbook_args | <%= cb.ansible_playbook_args %> |
  })
end

# helper step that does the following:
# 1. figure out project and route information
Given /^I login to kibana logging web console$/ do
  cb.logging_console_url = route('kibana', service('kibana',project('openshift-logging', switch: false))).dns(by: admin)
  step %Q/I have a browser with:/, table(%{
    | rules        | lib/rules/web/images/logging/       |
    | rules        | lib/rules/web/console/base/         |
    | base_url     | <%= cb.logging_console_url %>       |
    })
  step %Q/I perform the :kibana_login web action with:/, table(%{
    | username   | <%= user.name %>                      |
    | password   | <%= user.password %>                  |
    | kibana_url | https://<%= cb.logging_console_url %> |
    | idp        | <%= env.idp %>                        |
    })
  # change the base url so we don't need to specifiy kibana url every time afterward in the rule file
  browser.base_url = cb.logging_console_url
end

Given /^I log out kibana logging web console$/ do
  cb.logging_console_url = route('kibana', service('kibana',project('openshift-logging', switch: false))).dns(by: admin)
  step %Q/I perform the :logout_kibana web action with:/, table(%{
    | kibana_url | https://<%= cb.logging_console_url %> |
  })
  browser.finalize
end

# ##  curl
# -H "Authorization: Bearer $USER_TOKEN"
# -H "Hawkular-tenant: $PROJECT"
# -H "Content-Type: application/json"
# -X POST/GET https://metrics.$SUBDOMAIN/hawkular/metrics/{gauges|metrics|counters}
### https://metrics.0227-ep7.qe.rhcloud.com/hawkular/metrics/metrics
# acceptable parameters are:
# 1. | project_name | name of project |
# 2. | type  | type of metrics you want to query {gauges|metrics|counters} |
# 3. | payload | for POST only, local path or url |
# 4. | metrics_id | for single POST payload that does not have 'id' specified and user want an id other than the default of 'datastore'
# NOTE: for GET operation, the data retrieved are stored in cb.metrics_data which is an array
# NOTE: if we agree to use a fixed name for the first part of the metrics URL, then we don't need admin access privilege to run this step.
When /^I perform the (GET|POST) metrics rest request with:$/ do | op_type, table |
  cb[:metrics] = env.metrics_console_url
  opts = opts_array_to_hash(table.raw)
  raise "required parameter 'path' is missing" unless opts[:path]
  bearer_token = opts[:token] ? opts[:token] : user.cached_tokens.first

  https_opts = {}
  https_opts[:proxy] = env.client_proxy if env.client_proxy
  https_opts[:headers] ||= {}
  https_opts[:headers][:accept] ||= "application/json"
  https_opts[:headers][:content_type] ||= "application/json"
  https_opts[:headers][:hawkular_tenant] ||= opts[:project_name]
  https_opts[:headers][:authorization] ||= "Bearer #{bearer_token}"
  https_opts[:headers].delete(:hawkular_tenant) if opts[:project_name] == ":false"
  metrics_url = cb.metrics + opts[:path]

  if op_type == 'POST'
    file_name = opts[:payload]
    if %w(http https).include? URI.parse(opts[:payload]).scheme
      # user given a http source as a parameter
      step %Q/I download a file from "#{opts[:payload]}"/
      file_name = @result[:file_name]
    end
    https_opts[:payload] = File.read(expand_path(file_name))

    # the payload JSON does not have 'id' specified, so we need to look for
    # metrics_id to be specified in the table or if not there, then we
    # default the id to 'datastore'
    unless YAML.load(https_opts[:payload]).first.keys.include? 'id'
      metrics_id = opts[:metrics_id].nil?  ? "datastore" : opts[:metrics_id]
      metrics_url = metrics_url + "/" + metrics_id
    end
    url = metrics_url + "/raw"
  else
    url = opts[:metrics_id] ? metrics_url + "/" + opts[:metrics_id] : metrics_url
  end
  cb.metrics_data = []

  @result = BushSlicer::Http.request(url: url, **https_opts, method: op_type)

  @result[:parsed] = YAML.load(@result[:response]) if @result[:success]
  if (@result[:parsed].is_a? Array) and (op_type == 'GET') and opts[:metrics_id].nil?
    @result[:parsed].each do | res |
      logger.info("Getting data from metrics id #{res['id']}...")
      query_url = url + "/" + res['id']
      # get the id to construct the metric_url to do the QUERY operation
      result = BushSlicer::Http.request(url: query_url, **https_opts, method: op_type)
      result[:parsed] = YAML.load(result[:response])
      cb.metrics_data << result
    end
  else
    cb.metrics_data << @result
  end
end
# unless project name is given we assume all logging pods are installed under the current project
Given /^all logging pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  cb.target_proj ||= 'openshift-logging'
  proj_name = cb.target_proj if proj_name.nil?
  ensure_destructive_tagged
  org_proj_name = project.name

  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "#{proj_name}" project/
  begin
    # check rc readiness for 3/4 logging components, fluentd does not have rc, so stick with pod readiness for that component
    if env.version_ge("3.11", user: user)
      # for OCP >= 3.11, logging-curator is a cronjob instead of a pod
      raise "Failed to find cronjob for curator" if cron_job('logging-curator').schedule.nil?
    else
      step %Q/a replicationController becomes ready with labels:/, table(%{
        | component=curator,logging-infra=curator,openshift.io/deployment-config.name=logging-curator,provider=openshift |
        })
    end
    step %Q/a replicationController becomes ready with labels:/, table(%{
      | component=es,logging-infra=elasticsearch |
      })
    step %Q/I wait until the ES cluster is healthy/
    # use daemon-set for flutentd check due to something fluentd pods can
    # redeploy and the original names are gone and we would stuck in a loop
    # waiting for pods that are no longer there.  Unfortunately daemonset for logging is only support for OCP >= 3.4
    if env.version_ge("3.4", user: user)
      step %Q/"logging-fluentd" daemonset becomes ready in the project/
    else
     step %Q/all existing pods are ready with labels:/, table(%{
       | component=fluentd,logging-infra=fluentd |
       })
    end
    step %Q/a replicationController becomes ready with labels:/, table(%{
      | component=kibana,logging-infra=kibana,provider=openshift |
      })
    # we need to check to see if ops is enabled, if enabled we need to do more
    # checking
    if cb.ini_style_config['OSEv3:vars'].dig('openshift_logging_use_ops') == 'true'
      step %Q/a replicationController becomes ready with labels:/, table(%{
        | component=kibana-ops,logging-infra=kibana,provider=openshift |
      })
      # check rc readiness for 3/4 logging components, fluentd does not have rc, so stick with pod readiness for that component
      if env.version_ge("3.11", user: user)
        # for OCP >= 3.11, logging-curator is a cronjob instead of a pod
        raise "Failed to find cronjob for curator" if cron_job('logging-curator-ops').schedule.nil?
      else
        step %Q/a replicationController becomes ready with labels:/, table(%{
          | component=curator,logging-infra=curator,openshift.io/deployment-config.name=logging-curator,provider=openshift |
        })
      end
      step %Q/a replicationController becomes ready with labels:/, table(%{
        | component=es-ops,logging-infra=elasticsearch |
      })
    end
  ensure
    step %Q/I use the "#{org_proj_name}" project/ unless org_proj_name.nil?
  end
end

## for OCP <= 3.4, the labels and number of pods are different so going to
#  use a different step name to differentiate
Given /^all deployer logging pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  proj_name = project.name if proj_name.nil?
  org_proj_name = project.name
  if proj_name == 'logging'
    ensure_destructive_tagged
    step %Q/I switch to cluster admin pseudo user/
    project(proj_name)
  end
  begin
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=curator |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=curator-ops |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=es |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=es-ops |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=fluentd |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | component=kibana |
      })
     step %Q/all existing pods are ready with labels:/, table(%{
      | component=kibana-ops |
      })
  ensure
    project(org_proj_name)
  end
end

# we force all metrics pods to be installed under the project 'openshift-infra'
Given /^all metrics pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  if cb.install_prometheus
    step %Q/all prometheus related pods are running in the "#{proj_name}" project/
  else
    step %Q/all hawkular related pods are running in the "#{proj_name}" project/
  end
end
# HOA is short for Hawkular Openshift Agent
Given /^all Hawkular agent related resources exist in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_admin_tagged
  proj_name ||= "default"
  project(proj_name)

  step %Q/a pod becomes ready with labels:/, table(%{
    | name=hawkular-openshift-agent|
  })
  step %Q/I check that the "hawkular-openshift-agent" daemonset exists/
  step %Q/I check that the "hawkular-openshift-agent" service_account exists/
  step %Q/I check that the "hawkular-openshift-agent" clusterrole exists/
  step %Q/I check that the "hawkular-openshift-agent-configuration" config_map exists/
end

# HOA pod is gone along with
# daemonset/hawkular-openshift-agent
# sa/hawkular-openshift-agent
# configmap/hawkular-openshift-agent-configuration
# clusterrole/hawkular-openshift-agent
Given /^no Hawkular agent resources exist in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_admin_tagged
  proj_name ||= "default"
  project(proj_name)
  #
  step %Q/all existing pods die with labels:/, table(%{
    | name=hawkular-openshift-agent|
  })
  step %Q/the daemonset named "hawkular-openshift-agent" does not exist in the project/
  step %Q/the configmap named "hawkular-openshift-agent-configuration" does not exist in the project/
  step %Q/the service_account named "hawkular-openshift-agent" does not exist in the project/
  step %Q/the clusterrole named "hawkular-openshift-agent" does not exist in the project/
end


Given /^all hawkular related pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  target_proj = proj_name.nil? ? "openshift-infra" : proj_name
  raise ("Metrics must be installed into the 'openshift-infra") if target_proj != 'openshift-infra'

  org_proj_name = project.name
  org_user = user
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  project(target_proj)
  heapster_only = (cb.ini_style_config.params['OSEv3:vars'].keys.include? 'openshift_metrics_heapster_standalone') and (cb.ini_style_config.params['OSEv3:vars']['openshift_metrics_heapster_standalone'] == 'true')
  begin
    step %Q/I wait until replicationController "hawkular-cassandra-1" is ready/ unless heapster_only
    step %Q/I wait until replicationController "hawkular-metrics" is ready/ unless heapster_only
    step %Q/I wait until replicationController "heapster" is ready/
  ensure
    @user = org_user if org_user
    project(org_proj_name)
  end
end

# unlike Hawkular metrics, Prometheus can be installed under any project (like
# for logging).  It's default to 'project_metrics'
Given /^all prometheus related pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_destructive_tagged
  target_proj = proj_name.nil? ? "openshift-metrics" : proj_name

  org_proj_name = project.name
  org_user = user
  step %Q/I switch to cluster admin pseudo user/
  project(target_proj)
  begin
    step %Q/all existing pods are ready with labels:/, table(%{
      | app=prometheus |
      })
    # check pods that are only valid for OCP >= 3.9
    if env.version_ge("3.9", user: user)
      step %Q/all existing pods are ready with labels:/, table(%{
        | app=prometheus-node-exporter |
      })
    end
  ensure
    @user = org_user if org_user
    project(org_proj_name)
  end
end

# Metering installation require openshift-cluster-monitoring to be installed and functioning
Given /^all openshift-monitoring related pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_admin_tagged
  target_proj = proj_name.nil? ? "openshift-monitoring" : proj_name

  org_proj_name = project.name
  org_user = user
  step %Q/I switch to cluster admin pseudo user/
  raise "openshift-monitoring needs to be installed" unless project(target_proj).exists?
  begin
    step %Q/all existing pods are ready with labels:/, table(%{
      | app=prometheus |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | app=node-exporter |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | alertmanager=main,app=alertmanager |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | app=cluster-monitoring-operator |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | app=grafana |
      })
    step %Q/all existing pods are ready with labels:/, table(%{
      | k8s-app=prometheus-operator |
      })
  ensure
    @user = org_user if org_user
    project(org_proj_name)
  end
end

# verify all metering pods are in the RUNNING state
# expected pods are listed here:
# https://raw.githubusercontent.com/openshift-qe/output_references/master/metering/pod_labels.out
# the longest chain of deps is metering -> presto -> hive & hdfs
# so metering cant be ready until presto is ready
# presto can't be ready until hive is ready
# and metering can't be ready until presto can write to hdfs.
#
Given /^all metering related pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_destructive_tagged
  target_proj = proj_name.nil? ? "openshift-metering" : proj_name
  step %Q/I switch to cluster admin pseudo user/
  project(target_proj)
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=metering-operator |
  })
  # XXX: HDFS is not disabled by deafult, only check it if it's enabled
  if pod('hdfs-datanode-0').exists?
    step %Q/a pod becomes ready with labels:/, table(%{
      | app=hdfs-datanode |
    })
    step %Q/a pod becomes ready with labels:/, table(%{
      | app=hdfs-namenode |
    })
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=hive|
  })

  step %Q/a pod becomes ready with labels:/, table(%{
    | app=presto |
  })
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=reporting-operator |
  })
end

# default (install|uninstall) inventory is made up of these parts depending on the operation
# 1. default base inventory
# 2. extra logging parameters for logging only
# 3. extra metrics parameters for metrics only
Given /^I construct the default (install|uninstall) (logging|metrics|prometheus|metering) inventory$/ do |op, svc_type|
  base_inventory_url = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_base_inventory"

  step %Q/I parse the INI file "<%= "#{base_inventory_url}" %>"/
  # now get the extra parameters for install depending on the svc_type
  params_inventory_url = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_#{op}_#{svc_type}_params"
  step %Q/I parse the INI file "<%= "#{params_inventory_url}" %>" to the :params_inventory clipboard/

  cb.ini_style_config['OSEv3:vars'].merge!(cb.params_inventory['OSEv3:vars'])
end

# Parameters in the inventory that need to be replaced should be in ERB format
# if no project name is given, then we assume will use the project mapping of
# logging ==> 'openshift-logging', metrics ==> 'openshift-infra|openshift-metrics' (hawkular|prometheus)
#
# We divide the inventory loading process into two steps
# 1. load the default install|uninstall inventoroy depending on the operation.
# 2. load the inventory specified in the test if given and merge it with the result from step 1.
Given /^(logging|metrics|metering) service is (installed|uninstalled) with ansible using:$/ do |svc_type, op, table|
  ensure_destructive_tagged
  # check tht logging/metric is not installed in the target cluster already.
  ansible_opts = opts_array_to_hash(table.raw)
  # check to see if it's a negative test, skip post installation pod check if it's
  cb.negative_test = !!ansible_opts[:negative_test]
  cb.no_cleanup = !!ansible_opts[:no_cleanup]
  #cb.operation = op
  cb.svc_type = svc_type
  # prep the inventory file by setting the required clipboard for ERB
  # interpolation later
  ### XXX: we have to hardcode the children section due to the pasreconfig gem does not handle INI files that have keys but no values
  org_user = user
  cb.metrics_route_prefix = "metrics"
  cb.logging_route_prefix = "logs"
  # save user project where we'll instantiate the base-ansible-pod
  cb.org_project_for_ansible ||= project
  cb.subdomain = env.router_default_subdomain(user: admin, project: project('default', switch: false))
  step %Q/I store master major version in the :master_version clipboard/

  # get all schedulable nodes to be use as a replacement string in the inventory file
  schedulable_nodes = env.nodes.select(&:schedulable?).map(&:host).map(&:hostname)
  cb.nodes_text_replacement = schedulable_nodes.map{ |node_hostname|
    "#{node_hostname} openshift_public_hostname=#{node_hostname} openshift_node_group_name=\"node-config-infra\"\n"
    }.join("\n")
  # check early to see if we are dealing with Prometheus, but parsing out the inventory file, if none is
  # specified, we assume we are dealing with non-Prometheus metrics installation
  if ansible_opts.has_key? :inventory
    if svc_type == 'metering'
      # default to pull in the latest image for metering
      cb.metering_image ||= "quay.io/coreos/metering-helm-operator:latest"
    end
    step %Q/I parse the INI file "<%= "#{ansible_opts[:inventory]}" %>" to the :case_inventory clipboard/
    # figure out what service type we are installing, save it in clipboard for later
    params = cb.case_inventory.params['OSEv3:vars'].keys
    cb.svc_type = "prometheus" if params.any? { |p| p.include? 'openshift_prometheus' }
  end
  # we are enforcing that metrics to be installed into 'openshift-infra' for
  # hawkular and 'openshift-metrics' for Prometheus (unless inventory specify a
  # value) and openshift-logging for logging
  case cb.svc_type
  when 'metrics'
    target_proj = "openshift-infra"
  when 'logging'
    target_proj = "openshift-logging"
  when 'prometheus'
    target_proj = "openshift-metrics"
  when 'metering'
    target_proj = "openshift-metering"
  else
    raise "Unsupported service type"
  end
  cb.target_proj = target_proj
  ### for metering installation, there is a pre-requisite that openshift-monitoring is installed
  if target_proj == 'openshift-metering' and op == 'installed'
    step %Q/all openshift-monitoring related pods are running in the "openshift-monitoring" project/
  end
  # for scenarios that do reployed, we have registered clean-up so check if we are doing uninstall, then just skip uninstall if the project is gone
  if op == 'uninstalled'
    unless @projects.find { |p| p.name == cb.target_proj }
      logger.info("Target project #{cb.target_proj} already removed, skipping removal call")
      next
    end
  end

  step %Q"I construct the default #{op[0..-3]} #{cb.svc_type} inventory"

  if cb.ini_style_config
    # get testcase specific params into the final inventory file
    cb.ini_style_config["OSEv3:vars"].merge! cb.case_inventory['OSEv3:vars'] if cb.case_inventory
    params = cb.ini_style_config.params["OSEv3:vars"]
    if params.keys.include? 'openshift_prometheus_state'
      prometheus_state = params['openshift_prometheus_state']
      install_prometheus = prometheus_state
    end
    # check where user want to install Prometheus service and save it to the
    # clipboard which the post installation verification will need
    if params.keys.include? 'openshift_prometheus_namespace'
      cb.prometheus_namespace = params['openshift_prometheus_namespace']
      # user specified namespace overwrite it
      target_proj = cb.prometheus_namespace
    else
      cb.prometheus_namespace = 'openshift-metrics'
    end

    if params.keys.include? 'openshift_prometheus_node_selector'
      # parameter is in the form of "{\"region\" : \"region=ocp15538\"}" due to earlier ERB translation.
      # need to translate it back to ruby readable Hash
      node_selector_hash = YAML.load(params['openshift_prometheus_node_selector'])
      node_key = node_selector_hash.keys[0]

      node_selector = "#{node_key}=#{node_selector_hash[node_key]}"
    else
      # default hardcoded node selector
      node_selector = "region=infra"
    end

    # save it for other steps to use as a reference
    cb.install_prometheus = install_prometheus

    # for OCP >= 3.11 we need to label the nodes, so we just label the target node
    # regardless of OCP version
    step %Q/I select a random node's host/
    # for 3.10 prometheus installation need the label 'node-role.kubernetes.io/infra'
    step %Q{label "node-role.kubernetes.io/infra=true" is added to the node}
    step %Q/label "#{node_selector}" is added to the node/
  end

  unless cb.install_prometheus
    # for hawkular metrics installation, we enforce pods be installed under
    # 'openshift-infra'
    if svc_type == 'metrics' and cb.target_proj != 'openshift-infra'
      raise ("Metrics must be installed into the 'openshift-infra")
    end
  end

  logger.info("Performing operation '#{op[0..-3]}' to #{cb.target_proj}...")
  if op == 'installed' and not cb.no_cleanup
    step %Q/I register clean-up steps:/, table(%{
      | I remove #{svc_type} service using ansible |
      })
  else
    logger.info("*** NOTE: User elected not to cleanup installation! *** ")
  end

  raise "Must provide inventory option!" unless ansible_opts.keys.include? 'inventory'.to_sym

  step %Q/I create the "tmp" directory/

  new_path = nil
  if op == 'installed'
    new_path = "tmp/install_inventory"
  else
    new_path = "tmp/uninstall_inventory"
  end

  # we may not have the minor version of the image loaded. so just use the
  # major version label
  host = env.master_hosts.first
  # Need to construct the cert information if needed BEFORE inventory is processed
  if ansible_opts[:copy_custom_cert]
    key_name = "cucushift_custom.key"
    cert_name = "cucushift_custom.crt"

    # base_path corresponds to the inventory, for example #{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/OCP-12186/inventory
    base_path = "/tmp/#{File.basename(host.workdir)}/"
    cb.key_path = "#{base_path}/#{key_name}"
    cb.cert_path = "#{base_path}/#{cert_name}"
    cb.ca_crt_path = "#{base_path}/ca.crt"
  end

  inventory_io = StringIO.new
  # don't double quote values which cause some issues with arrays in openshift-ansible
  cb.ini_style_config.write(inventory_io, false)
  # due to limitation of ParseConfig library, it won't allow key without value,
  # so we hack this with 'children=to_be_replace'
  new_text = inventory_io.string.gsub(/\s=\s/, '=').
    gsub(/children=to_be_replaced/, "masters\netcd\nnodes\nnfs\n").
    gsub(/nodes=to_be_replaced/, cb.nodes_text_replacement)
  File.write(new_path, new_text)

  # create a tmp directory for files to be `oc rsync` to the pod created
  # 1. inventory
  # 2. libra.pem
  # 3. admin.kubeconfig from the master node
  pem_file_path = expand_path(env.master_hosts.first[:ssh_private_key])
  FileUtils.copy(pem_file_path, "tmp/")
  @result = admin.cli_exec(:oadm_config_view, flatten: true, minify: true)
  File.write(File.expand_path("tmp/admin.kubeconfig"), @result[:response])
  # save the service url for later use
  if svc_type == 'metrics'
    service_url = "#{cb.metrics_route_prefix}.#{cb.subdomain}"
  else
    service_url = "#{cb.logging_route_prefix}.#{cb.subdomain}"
  end

  begin
    # put base-ansible-pod in user project instead of system project per OPENSHIFTQ-12408
    step %Q/I have a pod with openshift-ansible playbook installed/
    @result = admin.cli_exec(:rsync, source: localhost.absolutize("tmp"), destination: "base-ansible-pod:/tmp", loglevel: 5, n: cb.org_project_for_ansible.name)
    step %Q/the step should succeed/
    step %Q/I switch to cluster admin pseudo user/
    # we need to scp the key and crt and ca.crt to the ansible installer pod
    # prior to the ansible install operation
    if ansible_opts[:copy_custom_cert]
      step %Q/the custom certs are generated with:/, table(%{
        | key       | #{key_name}    |
        | cert      | #{cert_name}   |
        | hostnames | #{service_url} |
        })
      # the ssl cert is generated in the first master, must make sure host
      # context is correct
      @result = host.exec_admin("cp -f /etc/origin/master/ca.crt #{host.workdir}")
      step %Q/the step should succeed/
      sync_certs_cmd = "oc project #{cb.org_project_for_ansible.name}; oc rsync #{host.workdir} base-ansible-pod:/tmp"
      @result = host.exec_admin(sync_certs_cmd)
      step %Q/the step should succeed/
    end
    if svc_type == 'logging'
      if env.version_le("3.7", user: user)
        ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/byo/openshift-cluster/openshift-logging.yml"
      else
        ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/openshift-logging/config.yml"
      end
    elsif svc_type == 'metering'
      if op == 'installed'
        ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/openshift-metering/config.yml"
      else
        ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/openshift-metering/uninstall.yml"
      end
    else
      if env.version_le("3.7", user: user)
        if install_prometheus
          ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/byo/openshift-cluster/openshift-prometheus.yml"
        else
          ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/byo/openshift-cluster/openshift-metrics.yml"
        end
      else
        if install_prometheus
          ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/openshift-prometheus/config.yml"
        else
          ansible_template_path = "/usr/share/ansible/openshift-ansible/playbooks/openshift-metrics/config.yml"
        end
      end
    end
    ### print out the inventory file
    logger.info("***** using the following user inventory *****")
    pod.exec("cat", "/tmp/#{new_path}", as: user)
    if ansible_opts[:playbook_args] and ansible_opts[:playbook_args].length > 0
      cb.ansible_playbook_args = ansible_opts[:playbook_args]
      playbook_cmd = %W(ansible-playbook -i /tmp/#{new_path} #{ansible_opts[:playbook_args]} #{conf[:ansible_log_level]}  #{ansible_template_path})
    else
      playbook_cmd = %W(ansible-playbook -i /tmp/#{new_path} #{conf[:ansible_log_level]}  #{ansible_template_path})
    end
    @result = pod.exec(*playbook_cmd, as: user)
    ## save the output of the playbook run into a clipboard in case we need to check for playbook output
    cb.playbook_output = @result[:stdout]
    #step %Q/I execute on the pod:/, table(%{
    #  | ansible-playbook | -i | /tmp/#{new_path} | #{conf[:ansible_log_level]} | #{ansible_template_path} |
    #  })
    # XXX: skip the check for now due to https://bugzilla.redhat.com/show_bug.cgi?id=1512723
    step %Q/the step should succeed/ unless cb.negative_test
    # the openshift-ansible playbook restarts master at the end, we need to run the following to just check the master is ready.
    step %Q/the master is operational/
    if op == 'installed'
      if svc_type == 'logging'
        # there are 4 pods we need to verify that should be running  logging-curator,
        # logging-es, logging-fluentd, and logging-kibana
        if cb.negative_test
          logger.warn("Skipping post installation check due to negative test")
        else
          step %Q/all logging pods are running in the "#{target_proj}" project/
        end
      elsif svc_type == 'metering'
        if cb.negative_test
          logger.warn("Skipping post installation check due to negative test")
        else
          # for metering we need to create the
          @result = user.cli_exec(:create, f: "#{ENV['BUSHSLICER_HOME']}/testdata/metering/default-storageclass-values.yaml")
          step %Q/all metering related pods are running in the "#{target_proj}" project/
          step %Q/I wait for the "openshift-metering" metering to appear/
        end
      else
        if cb.negative_test
          logger.warn("Skipping post installation check due to negative test")
        else
          step %Q/all metrics pods are running in the "#{target_proj}" project/
          step %Q/I verify metrics service is functioning/
        end
      end
    else
      if svc_type == 'logging'
        step %Q/there should be 0 logging service installed/
      else
        # we only enforce that no existing metrics service if it's not
        # Prometheus
        if cb.install_prometheus
          step %Q/I wait for the resource "project" named "openshift-metrics" to disappear within 60 seconds/
        else
          # for hawkular
          step %Q/there should be 0 metrics service installed/
        end
      end
    end
  ensure
    # @user = org_user if org_user
    project(cb.target_proj)
  end
end

# download any ini style config file and translate the ERB and store the result
# into the clipboard index :ini_style_config
Given /^I parse the INI file #{QUOTED}(?: to the#{OPT_SYM} clipboard)?$/ do |ini_style_config, cb_name|
  cb_name ||= :ini_style_config
  # use ruby instead of step to bypass user restriction
  step %Q/I download a file from "<%= "#{ini_style_config}" %>"/
  step %Q/the step should succeed/
  # convert ERB elements in they exist
  loaded = ERB.new(File.read(@result[:file_name])).result binding
  File.write(@result[:file_name], loaded)
  config = ParseConfig.new(@result[:file_name])
  cb[cb_name] = config
end
Given /^logging service is installed in the#{OPT_QUOTED} project using deployer:$/ do |proj, table|
  ensure_destructive_tagged
  deployer_opts = opts_array_to_hash(table.raw)
  raise "Must provide deployer configuration file!" unless deployer_opts.keys.include? 'deployer_config'.to_sym
  logger.info("Performing logging installation using deployer")
  # step %Q/the first user is cluster-admin/
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "<%= project.name %>" project/
  step %Q/I store master major version in the :master_version clipboard/
  cb.subdomain = env.router_default_subdomain(user: admin, project: project('default'))
  #env.router_default_subdomain(user: user, project: project)

  unless cb.deployer_config
    step %Q/I download a file from "<%= "#{deployer_opts[:deployer_config]}" %>"/
    logger.info("***** using the following deployer config *****")
    logger.info(@result[:response])
    cb.deployer_config = YAML.load(ERB.new(File.read(@result[:abs_path])).result binding)
    logger.info("***** interpreted deployer config *****")
    logger.info(cb.deployer_config.to_yaml)
  end
  step %Q/I register clean-up steps:/, table(%{
    | I remove logging service installed in the project using deployer |
    })
  # create the configmap
  step %Q|I run oc create over ERB URL: #{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/logging_deployer_configmap.yaml |
  step %Q/the step should succeed/
  # must create a label or else installation will fail
  registry_nodes = BushSlicer::Node.get_labeled(["registry"], user: user)
  registry_nodes.each do |node|
    step %Q/label "logging-infra-fluentd=true" is added to the "#{node.name}" node/
    step %Q/the step should succeed/
  end

  # create new secret
  step %Q/I run the :new_secret client command with:/, table(%{
    | secret_name     | logging-deployer  |
    | credential_file | nothing=/dev/null |
  })
  step %Q/the step should succeed/

  # create necessary accounts
  step %Q/I run the :new_app client command with:/, table(%{
    | app_repo | logging-deployer-account-template |
    })
  #step %Q/the step should succeed/
  step %Q/cluster role "oauth-editor" is added to the "system:serviceaccount:<%= project.name %>:logging-deployer" service account/
  step %Q/SCC "privileged" is added to the "system:serviceaccount:<%= project.name %>:aggregated-logging-fluentd" service account/
  step %Q/cluster role "cluster-reader" is added to the "system:serviceaccount:<%= project.name %>:aggregated-logging-fluentd" service account/
  raise "Unable to get master version" if cb.master_version.nil?
  if cb.master_version >= "3.4"
    step %Q/cluster role "rolebinding-reader" is added to the "system:serviceaccounts:<%= project.name %>:aggregated-logging-elasticsearch" service account/
  end

  step %Q/I run the :new_app client command with:/, table(%{
      | app_repo | logging-deployer-template |
                                                         })
  step %Q/the step should succeed/
  # we need to wait for the deployer to be completed first
  step %Q/status becomes :succeeded of 1 pod labeled:/, table(%{
    | app=logging-deployer-template |
    | logging-infra=deployer        |
    | provider=openshift            |
    })
  step %Q/I wait for the container named "deployer" of the "#{pod.name}" pod to terminate with reason :completed/
  # verify logging is installed
  step %Q/all deployer logging pods are running in the project/
end

# following instructions here:
# we must use the project 'openshift-infra'
Given /^metrics service is installed in the project using deployer:$/ do |table|
  ensure_destructive_tagged
  org_proj_name = project.name
  org_user = user
  target_proj = 'openshift-infra'
  deployer_opts = opts_array_to_hash(table.raw)
  raise "Must provide deployer configuration file!" unless deployer_opts.keys.include? 'deployer_config'.to_sym
  logger.info("Performing metrics installation by deployer")
  step %Q/I switch to cluster admin pseudo user/
  project(target_proj)

  step %Q/I store master major version in the :master_version clipboard/
  cb.subdomain = env.router_default_subdomain(user: admin, project: project('default'))

  # sanity check, fail early if we can't get the master version
  raise "Unable to get subdomain" if cb.subdomain.nil?

  unless cb.deployer_config
    step %Q/I download a file from "<%= "#{deployer_opts[:deployer_config]}" %>"/
    cb.deployer_config = YAML.load(ERB.new(File.read(@result[:abs_path])).result binding)
  end
  metrics_deployer_params = [
    "HAWKULAR_METRICS_HOSTNAME=metrics.#{cb.subdomain}",
    "IMAGE_PREFIX=#{product_docker_repo}openshift3/",
    "IMAGE_VERSION=#{cb.master_version}",
    "MASTER_URL=#{env.api_endpoint_url}",
  ]
  # check to see what the user specified any parameters to be different from default values
  # We are treating all UPCASE params as metrics deployer specific parameter
  user_defined_params = []
  deployer_opts.each do |k, v|
    if k.upcase == k
      user_defined_params << k
      metrics_deployer_params << "#{k}=#{v}"
    end
  end
  # XXX: for automation testing, we are overriding the following default config unless user specified them in the top level step call
  cb.deployer_config['metrics'].keys.each do | k |
    # make sure we are only adding user defined
    if k.upcase == k
      unless user_defined_params.include? k
        metrics_deployer_params << "#{k}=#{cb.deployer_config['metrics'][k]}"
      end
    end

  end
  #   the param is set by user
  step %Q/I register clean-up steps:/, table(%{
    | I remove metrics service installed in the project using deployer |
    })
  # create new secret
  step %Q/I run the :new_secret client command with:/, table(%{
    | secret_name     | metrics-deployer  |
    | credential_file | nothing=/dev/null |
    | n               | #{target_proj}    |
  })
  step %Q/the step should succeed/

  # create necessary accounts
  step %Q/I run the :create client command with:/, table(%{
    | f | <%= cb.deployer_config['metrics']['serviceaccount_metrics_deployer'] %> |
    | n | <%= project.name %>                                                     |
    })
  step %Q/the step should succeed/
  step %Q/cluster role "edit" is added to the "system:serviceaccount:<%= project.name %>:metrics-deployer" service account/
  step %Q/the step should succeed/
  step %Q/cluster role "view" is added to the "system:serviceaccount:<%= project.name %>:hawkular" service account/
  step %Q/the step should succeed/
  step %Q/cluster role "cluster-reader" is added to the "heapster" service account/
  step %Q/the step should succeed/
  @result = user.cli_exec(:new_app, template: "metrics-deployer-template",
    n: project.name, param: metrics_deployer_params)

  step %Q/the step should succeed/
  # we need to wait for the deployer to be completed first
  step %Q/status becomes :running of 1 pod labeled:/, table(%{
    | app=metrics-deployer-template |
    | logging-infra=deployer        |
    | provider=openshift            |
    })
  step %Q/I wait for the container named "deployer" of the "#{pod.name}" pod to terminate with reason :completed/
  # verify metrics is installed
  step %Q/all metrics pods are running in the project/
  step %Q/I verify metrics service is functioning/
  # we need to switch back to normal user and the original project
  @user = org_user
  project(org_proj_name)
end

Given /^I remove logging service installed in the#{OPT_QUOTED} project using deployer$/ do |proj|
  ensure_destructive_tagged
  if env.version_ge("3.2", user: user)
    step %Q/I run the :new_app admin command with:/, table(%{
      | app_repo | logging-deployer-template |
      | param    | MODE=uninstall            |
                                                            })
    # due to bug https://bugzilla.redhat.com/show_bug.cgi?id=1467984 we need to
    # do manual cleanup on some of the resources that are not deleted by
    # project removal
    @result = admin.cli_exec(:delete, {object_type: 'clusterrole', object_name_or_id: 'oauth-editor', n: 'default'})
    @result = admin.cli_exec(:delete, {object_type: 'clusterrole', object_name_or_id: 'daemonset-admin ', n: 'default'})
    @result = admin.cli_exec(:delete, {object_type: 'clusterrole', object_name_or_id: 'rolebinding-reader', n: 'default'})
    @result = admin.cli_exec(:delete, {object_type: 'oauthclients', object_name_or_id: 'kibana-proxy', n: 'default'})
  end
end

# the requirement has always been metrics is installed under the project
# openshift-infra
Given /^I remove metrics service installed in the#{OPT_QUOTED} project using deployer$/ do |proj_name|
  ensure_destructive_tagged
  proj_name = 'openshift-infra' if proj_name.nil?
  @result = admin.cli_exec(:delete, object_name_or_id: 'all,secrets,sa,templates', l: 'metrics-infra', 'n': 'openshift-infra')
  @result = admin.cli_exec(:delete, {object_type: 'sa', object_name_or_id: 'metrics-deployer', 'n': 'openshift-infra'})
  @result = admin.cli_exec(:delete, {object_type: 'secrets', object_name_or_id: 'metrics-deployer', 'n': 'openshift-infra'})
end


# check openshift-ansible is installed in a node, if not, then do rpm or yum
# installation
Given /^openshift-ansible is installed in the #{QUOTED} node$/ do | node_name |
  ensure_admin_tagged
  # switch to use the target node
  host = node(node_name).host
  check_host = host.exec("cat /etc/redhat-release")
  raise "No release information in node" unless check_host[:success]

  if check_host[:response].include? "Atomic Host" and !conf[:openshift_ansible_installer].start_with? 'git'
    raise "Installation method not support currently in Atomic Host"
  end

  res = host.exec_admin("ls /usr/share/ansible/openshift-ansible/")
  unless res[:success]
    if conf[:openshift_ansible_installer] == 'yum'
      logger.info("Installing openshift-ansible via yum")
      yum_install_cmd = "yum -y install openshift-ansible*"
      res = host.exec_admin(yum_install_cmd)
      has_playbooks = host.exec_admin("ls /usr/share/ansible/openshift-ansible/playbooks")
      raise "Unable to install openshift-ansible via yum" unless has_playbooks[:success]
    elsif conf[:openshift_ansible_installer] == 'git'
      pass
    else
      raise "Unsupported installation method"
    end
  end
end

# wrapper step to spin up a ansible-pod based on ose/ansible docker image
# To override the image tag from the puddle, we need to do something like
# export BUSHSLICER_CONFIG='{"global":
#                             {"base_ansible_image_tag": "latest",
#                             {"ansible_image_src: "openshift3/ose-ansible"}}'
# possible 'image_src' values are openshift/origin-ansible (master) or
# openshift3/ose-ansible (official released image for OCP).  Please note that
# the ose-ansible won't have WIP release labels
Given /^I have a pod with openshift-ansible playbook installed$/ do
  ensure_admin_tagged
  cb.base_ansible_image_tag = conf[:base_ansible_image_tag]
  step %Q/I store master major version in the :master_version clipboard/ unless cb.master_version
  cb.base_ansible_image_tag ||= "v#{cb.master_version}"
  cb.ansible_image_src = conf[:ansible_image_src]
  cb.ansible_image_src ||= "openshift3/ose-ansible"
  cb.org_project_for_ansible ||= project
  # we need to save the original project name for post test cleanup
  # to save time we are going to check if the base-ansible-pod already exists
  # use admin user to get the information so we don't need to switch user.
  unless pod("base-ansible-pod", cb.org_project_for_ansible).exists?(user: admin)
    cb.proxy_value = env.proxy
    logger.info("Proxy set to: #{cb.proxy_value}")
    step %Q/I switch to cluster admin pseudo user/
    step %Q{I use the "<%= cb.org_project_for_ansible.name %>" project}
    step %Q{I run oc create over ERB URL: #{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/base_ansible_ose.yaml}
    step %Q/the step should succeed/
    step %Q/the pod named "base-ansible-pod" becomes ready/

    # check to see if openshift-ansible is already installed
    @result = pod.exec("bash", "-c", "ls /usr/share/ansible/openshift-ansible", as: user)
    raise "openshift-ansible binanary was not found in pod" unless @result[:success]
  end
end



Given /^I save installation inventory from master to the#{OPT_SYM} clipboard$/ do | cb_name |
  ensure_admin_tagged

  cb_name ||= :installation_inventory
  host = env.master_hosts.first
  qe_inventory_file = 'qe-inventory-host-file'
  host.copy_from("/tmp/#{qe_inventory_file}", "")
  if File.exist? qe_inventory_file
    config = ParseConfig.new(qe_inventory_file)
    cb[cb_name] = config.params
  else
    raise "'#{qe_inventory_file}' does not exists"
  end
end


### mother of all logging/metrics steps: Call this regardless of master version
### assume we already have called the following step to create a project name
### I create a project with non-leading digit name
# use this step if we just want to use default values
Given /^(logging|metrics|metering) service is installed in the system$/ do | svc |
  if env.version_ge("3.5", user: user)
    param_name = 'inventory'
    param_value = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_base_inventory"
  else
    param_name = 'deployer_config'
    param_value = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_deployer.yaml"
  end
  step %Q/#{svc} service is installed in the system using:/, table(%{
    | #{param_name} | #{param_value} |
    })

end

Given /^(logging|metrics|metering) service is installed in the system using:$/ do | svc, table |
  ensure_destructive_tagged

  params = opts_array_to_hash(table.raw) unless table.nil?
  if env.version_ge("3.5", user: user)
    # use ansible
    inventory = params[:inventory]
    logger.info("Installing #{svc} using ansible")
    step %Q/#{svc} service is installed with ansible using:/, table(%{
      | inventory | #{inventory} |
      })
  else
    # use deployer
    deployer_config = params[:deployer_config]
    logger.info("Installing #{svc} using deployer")
    step %Q/#{svc} service is installed using deployer:/, table(%{
      | deployer_config | #{deployer_config}|
      })
  end
end

### helper methods essential for logging and metrics

# we assume user is authenticated already
Given /^the metrics service status in the metrics web console is #{QUOTED}$/ do |status|
  metrics_service_status =  browser.page_html.match(/Metrics Service :(\w+)/)[1]
  matched = metrics_service_status == status
  raise "Expected #{status}, got #{metrics_service_status}" unless matched
end

Given /^I verify metrics service is functioning$/ do
  if cb.install_prometheus
    step %Q/I verify Prometheus metrics service is functioning/
  end
end

# for Prometheus installation, we do the following checks to verify ansible
# installation of the service is successful
# 1. oc rsh ${prometheus_pod}; curl localhost:9090/metrics
# 2. oc rsh ${prometheus_pod}
# 3. curl localhost:9093/api/v1/alerts
Given /^I verify Prometheus metrics service is functioning$/ do
  ensure_admin_tagged
  # make sure we are talking to the right project and pod
  prometheus_namespace = cb.prometheus_namespace ? cb.prometheus_namespace : "openshift-metrics"
  project(prometheus_namespace)
  step %Q/a pod becomes ready with labels:/, table(%{
     | app=prometheus |
   })
  metrics_api_cmd = "curl localhost:9090/api/v1/query?query=up&time"
  @result = pod.exec("bash", "-c", metrics_api_cmd, as: user)
  step %Q/the step should succeed/
  expected_api_query_pattern = '"status":"success"'
  raise "Did not find expected api query pattern '#{expected_alerts_pattern}', got #{@result[:response]}" unless @result[:response].include? expected_api_query_pattern
  metrics_check_cmd = "curl localhost:9090/metrics"
  @result = pod.exec("bash", "-c", metrics_check_cmd, as: user)
  step %Q/the step should succeed/
  expected_metrics_pattern = "prometheus_engine_queries 0"
  raise "Did not find expected metrics pattern '#{expected_metrics_pattern}', got #{@result[:response]}" unless @result[:response].include? expected_metrics_pattern
  alerts_check_cmd = "curl localhost:9093/api/v1/alerts"
  @result = pod.exec("bash", "-c", alerts_check_cmd, as: user)
  step %Q/the step should succeed/
  expected_alerts_pattern = '"status":"success"'
  raise "Did not find expected alerts pattern '#{expected_alerts_pattern}', got #{@result[:response]}" unless @result[:response].include? expected_alerts_pattern
end


Given /^event logs can be found in the ES pod(?: in the#{OPT_QUOTED} project)?/ do |proj_name|
  project(proj_name) if proj_name   # change project context if necessary

  step %Q/a pod becomes ready with labels:/, table(%{
    | component=es,logging-infra=elasticsearch,provider=openshift |
  })
  check_es_pod_cmd = "curl -XGET --cacert /etc/elasticsearch/secret/admin-ca --cert /etc/elasticsearch/secret/admin-cert --key /etc/elasticsearch/secret/admin-key 'https://localhost:9200/_search?pretty&size=5000&q=kubernetes.event.verb:*' --insecure | python -c \"import sys, json; print json.load(sys.stdin)['hits']['total']\""

  seconds = 5 * 60
  total_hits_regexp = /^(\d+)$/
  success = wait_for(seconds) {
    @result = pod.exec("bash", "-c", check_es_pod_cmd, as: user)
    if @result[:success]
      # now check we get a total hits > 0
      total_hits_match = total_hits_regexp.match(@result[:response])
      if total_hits_match
        total_hits_match[1].to_i > 0
      end
    else
      raise 'Failed to retrive data from eventrouter pod'
    end
  }
  raise "ES pod '#{pod.name}' did not see any hits within #{seconds} seconds" unless success
end

When /^I wait(?: (\d+) seconds)? for the #{QUOTED} index to appear in the ES pod(?: with labels #{QUOTED})?$/ do |seconds, index_name, pod_labels|
  # pod type check for safeguard
  if pod_labels
    step %Q/a pod becomes ready with labels:/, table(%{
      | #{pod_labels} |
    })
  else
    raise 'Current pod must be of type ES' unless pod.labels.key? 'component' and pod.labels['component'].start_with? 'es'
  end

  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 10 * 60
  index_data = nil
  success = wait_for(seconds) {
    step %Q/I get the "#{index_name}" logging index information from a pod with labels "#{pod_labels}"/
    res = cb.index_data
    if res
      index_data = res
      # exit only health is not 'red' and index is 'open' and the docs.count > 0
      # XXX note, to be more correct, we should check that the index is not red
      # for an extended persiod.  The tricky part is how to define extended period????
      # for now, just consider it not red to be good
      #https://www.elastic.co/guide/en/elasticsearch/reference/5.6/cluster-health.html
      res['health'] != 'red' and res['status'] == 'open' and res['docs.count'].to_i > 0
    end
  }
  raise "Index '#{index_name}' failed to appear in #{seconds} seconds" unless success
end

# must execute in the es-xxx pod
# @return stored data into cb.index_data
When /^I get the #{QUOTED} logging index information(?: from a pod with labels #{QUOTED})?$/ do | index_name, pod_labels |
  # pod type check for safeguard
  if pod_labels
    step %Q/a pod becomes ready with labels:/, table(%{
      | #{pod_labels} |
    })
  else
    raise 'Current pod must be of type ES' unless pod.labels.key? 'component' and pod.labels['component'].start_with? 'es'
  end

  step %Q/I perform the HTTP request on the ES pod with labels "#{pod_labels}":/, table(%{
    | relative_url | _cat/indices?format=JSON |
    | op           | GET                      |
  })
  res = @result[:parsed].find {|e| e['index'].start_with? index_name}
  cb.index_data = res
end

# just do the query, check result outside of the step.
# @relative_url: relative url of the query
# @op: operation we want to perform (GET, POST, DELETE, and etc)
Given /^I perform the HTTP request on the ES pod(?: with labels #{QUOTED})?:$/ do |pod_labels, table|
  # pod type check for safeguard
  if pod_labels
    step %Q/a pod becomes ready with labels:/, table(%{
      | #{pod_labels} |
    })
  else
    raise 'Current pod must be of type ES' unless pod.labels.key? 'component' and pod.labels['component'].start_with? 'es'
  end
  opts = opts_array_to_hash(table.raw)
  # sanity check
  required_params = [:op, :relative_url]
  required_params.each do |param|
    raise "Missing parameter '#{param}'" unless opts[param]
  end
  # if user specify token, curl command should use it instead of usering the system cert

  if opts[:token]
    #query_opts = "-H \"Authorization: Bearer #{opts[:token]}\""
    query_opts = "-H \"Authorization: Bearer #{opts[:token]}\" -H \"X-Forwarded-For: 127.0.0.1\""
  else
    query_opts = "--insecure --cacert /etc/elasticsearch/secret/admin-ca --cert /etc/elasticsearch/secret/admin-cert --key /etc/elasticsearch/secret/admin-key"
  end
  query_cmd = "curl -sk -X #{opts[:op]} #{query_opts} 'https://localhost:9200/#{opts[:relative_url]}'"
  @result = pod.exec("bash", "-c", query_cmd, as: admin, container: 'elasticsearch')
  if @result[:success]
    @result[:parsed] = YAML.load(@result[:response])
    # curl returns 0 even with a http code of 403, we force it to match.
    if @result[:parsed].is_a? Hash and @result[:parsed].has_key? 'status'
      @result[:exitstatus] = @result[:parsed]['status']
    end
  else
    raise "HTTP operation failed with error, #{@result[:response]}"
  end
end



# just call diagnostics w/o giving any arguments
# dignostics command line options are different depending on the version of OCP, for OCP <= 3.7, the command must
# be run from the master's host.  With OCP > 3.7, we can run form either localhost or master host.  For consistency we
# just alway run from master
# reuturn: @result should contain the run status
Given /^I run logging diagnostics$/ do
  ensure_admin_tagged
  if env.version_gt("3.7", user: user)
    diag_cmd = "oc adm diagnostics AggregatedLogging --logging-project=#{project.name}"
  else
    diag_cmd = "oc adm diagnostics AggregatedLogging"
  end
  host = env.master_hosts.first

  @result = host.exec(diag_cmd)
end

#
Given /^I generate a basic inventory with cluster hosts information$/ do
  inventory_name = "base_inventory"
  base_inventory_url = "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_base_inventory"
  step %Q/I parse the INI file "<%= "#{base_inventory_url}" %>"/
  inventory_io = StringIO.new
  # don't double quote values which cause some issues with arrays in openshift-ansible
  cb.ini_style_config.write(inventory_io, false)
  new_text = inventory_io.string.gsub(/\s=\s/, '=').
    gsub(/children=to_be_replaced/, "masters\netcd\nnodes\n")
    gsub(/nodes=to_be_replaced/, cb.nodes_text_replacement)
  File.write(inventory_name, new_text)
end


# run a specific playbook within the base-ansible pod that we generated when we installed logging/metric service
# 1. PREREQ: playbook is already in the pod (we assume a previous step sets up )
# 2. oc rsync base_inventory, admin config and ssh key over to the pod
# parameters
#   a. playbook_path, path to the playbook file relative to /tmp/<synced_dir_from_localhost>
#   b. clean_up_arg (optional, only applies to playbooks that needs clean up arguements).  For example, logging

Given /^I run the following playbook on the#{OPT_QUOTED} pod:$/ do |pod_name, table|
  pod_name ||= pod.name
  opts = opts_array_to_hash(table.raw)
  playbook_path = opts[:playbook_path]
  clean_up_arg = opts[:clean_up_arg]
  dst_dir_path = "tmp"
  base_inventory_name = "base_inventory"
  _pod = pod(pod_name)
  _user = user
  FileUtils.mkdir_p("#{dst_dir_path}") unless Dir.exists? dst_dir_path
  step %Q/I generate a basic inventory with cluster hosts information/
  FileUtils.move(base_inventory_name, dst_dir_path)
  step %Q/ssh key for accessing nodes is copied to the pod/

  # register clean up if user calls for it.
  if clean_up_arg
    teardown_add {
      clean_args = %W(ansible-playbook -i /tmp/#{dst_dir_path}/#{base_inventory_name} #{conf[:ansible_log_level]} /tmp/#{dst_dir_path}/#{playbook_path} #{clean_up_arg})
      @result = _pod.exec(*clean_args, as: _user)
      raise "Failed when running cleanup playbook: #{@result[:stderr]}" unless @result[:success]
    }
  end

  args = %W(ansible-playbook -i /tmp/#{dst_dir_path}/#{base_inventory_name} #{conf[:ansible_log_level]} /tmp/#{dst_dir_path}/#{playbook_path})
  @result = _pod.exec(*args, as: _user)
  raise "Failed when running playbook: #{@result[:stderr]}" unless @result[:success]
end

Given /^I get the #{QUOTED} node's prometheus metrics$/ do |node_name|
  # create secret for cert and key file
  res = env.master_hosts.first.exec("oc create secret generic kubelet-cert --from-file=/etc/origin/master/master.kubelet-client.crt -n #{project.name}")
  raise "Failed when creating kubelet-cert secret" unless res[:success]
  res = env.master_hosts.first.exec("oc create secret generic kubelet-key --from-file=/etc/origin/master/master.kubelet-client.key -n #{project.name}")
  raise "Failed when creating kubelet-key secret" unless res[:success]

  # create prom2json pod
  step %Q{I run oc create over "#{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/prom2json_pod.yaml" replacing paths:}, table(%{
      | ["metadata"]["name"] | pod-#{project.name} |
  })
  step %Q/the step should succeed/
  step %Q/the pod named "pod-#{project.name}" becomes ready/

  # get kubelet metrics and write to a file
  @result = pod.exec("/prom2json", "-cert=/cert/master.kubelet-client.crt", "-key=/key/master.kubelet-client.key", "-accept-invalid-cert=true", "https://#{node_name}:10250/metrics", as: user)
  raise "Failed when getting kubelet metrics" unless @result[:success]
  cb.node_metrics = BushSlicer::PrometheusMetricsData.new(@result[:stdout])
end

Given /^I check the #{QUOTED} prometheus rule in the #{QUOTED} project on the prometheus server$/ do | prometheus_rule_name, project_name |
  step %Q/I run the :exec client command with:/, table(%{
    | n                | openshift-monitoring                                                                          |
    | container        | prometheus                                                                                    |
    | pod              | prometheus-k8s-0                                                                              |
    | exec_command     | cat                                                                                           |
    | exec_command_arg | /etc/prometheus/rules/prometheus-k8s-rulefiles-0/#{project_name}-#{prometheus_rule_name}.yaml |
  })
  step %Q/the step should succeed/
end
