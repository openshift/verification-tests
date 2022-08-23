Given(/^the "([^"]*)" descheduler CR is restored from the "([^"]*)" after scenario$/) do |name, project_name|
  ensure_admin_tagged
  ensure_destructive_tagged
  org_descheduler = {}
  @result = admin.cli_exec(:get, resource: 'kubedescheduler', resource_name: name, o: 'yaml', n: project_name)
  if @result[:success]
    org_descheduler['spec'] = @result[:parsed]['spec']
    logger.info "descheduler restore tear_down registered:\n#{org_descheduler}"
  else
    raise "Could not get descheduler: #{name}"
  end
  patch_json = org_descheduler.to_json
  _admin = admin
  teardown_add {
    @result = admin.cli_exec(:get, resource: 'kubedescheduler', resource_name: name, o: 'yaml')
    if @result[:success] and @result[:parsed]['spec']['profileCustomizations']
      patch_pc_json = [{"op": "remove","path": "/spec/profileCustomizations"}].to_json
      opts_pc = {resource: 'kubedescheduler', resource_name: name, p: patch_pc_json, type: 'json' }
      @result_pc = _admin.cli_exec(:patch, **opts_pc)
      rasie "Cannot restore profileCustomizations" unless @result_pc[:success]
      opts = {resource: 'kubedescheduler', resource_name: name, p: patch_json, type: 'merge' }
    end
    opts = {resource: 'kubedescheduler', resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore descheduler: #{name}" unless @result[:success]
}
end

Given /^(cluster-kube-descheduler-operator) channel name is stored in the#{OPT_SYM} clipboard$/ do | packagemanifest, cb_name |
  cb_name = 'channel' unless cb_name
  descheduler_envs = env.descheduler_envs
  unless descheduler_envs.empty?
    case packagemanifest
    when "cluster-kube-descheduler-operator"
      envs = descheduler_envs[:kdo]
    end
  end
  step %Q/I use the "openshift-marketplace" project/
  # check if the packagemanifest exist
  raise "Packagemanifest #{packagemanifest} doesn't exist" unless package_manifest(packagemanifest).exists?

  if (descheduler_envs.empty?) || (envs.nil?) || (envs[:channel].nil?)
    version = cluster_version('version').version.split('-')[0].split('.').take(2).join('.')
    case version
    when '4.6','4.7','4.8','4.9','4.10'
      cb[cb_name] = version
    else
      cb[cb_name] = "stable"
    end
  else
    cb[cb_name] = envs[:channel]
  end
end

Given /^(cluster-kube-descheduler-operator) catalog source name is stored in the#{OPT_SYM} clipboard$/ do | packagemanifest, cb_name |
  cb_name = 'source' unless cb_name
  descheduler_envs = env.descheduler_envs
  unless descheduler_envs.empty?
    case packagemanifest
    when "cluster-kube-descheduler-operator"
      envs = descheduler_envs[:kdo]
    end
  end
  step %Q/I use the "openshift-marketplace" project/
  # check if the packagemanifest exist
  raise "Packagemanifest #{packagemanifest} doesn't exist" unless package_manifest(packagemanifest).exists?

  # get source name, if it's not set, use default source
  if (descheduler_envs.empty?) || (envs.nil?) || (envs[:catsrc].nil?)
    if catalog_source("qe-app-registry").exists?
      cb[cb_name] = "qe-app-registry"
    elsif catalog_source("redhat-operators").exists?
      cb[cb_name] = "redhat-operators"
    else
      cb[cb_name] = package_manifest(packagemanifest).catalog_source
    end
  else
    #raise "The specified catalog source doesn't exist" unless catalog_source(envs[:catsrc]).exists?
    cb[cb_name] = envs[:catsrc]
  end
end

Given /^kubedescheduler operator has been installed successfully$/ do
  ensure_destructive_tagged
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/evaluation of `cluster_version('version').version` is stored in the :ocp_cluster_version clipboard/
  step %Q/cluster-kube-descheduler-operator channel name is stored in the :kdo_channel clipboard/

  unless project('openshift-kube-descheduler-operator').exists?
    namespace_yaml = "#{BushSlicer::HOME}/testdata/descheduler/01_kd-project.yaml"
    @result = admin.cli_exec(:create, f: namespace_yaml)
    raise "Error creating namespace" unless @result[:success]
  end

  step %Q/I use the "openshift-kube-descheduler-operator" project/
  unless deployment('descheduler-operator').exists?
    unless operator_group('openshift-kube-descheduler-operator').exists?
      clo_operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/descheduler/02_kd-og.yaml"
      @result = admin.cli_exec(:create, f: clo_operator_group_yaml)
      raise "Error creating operatorgroup" unless @result[:success]
    end

    unless subscription('cluster-kube-descheduler-operator').exists?
      step %Q/I use the "openshift-marketplace" project/
      # first check packagemanifest exists for cluster-kube-descheduler-operator
      raise "Required packagemanifest 'cluster-kube-descheduler-operator' no found!" unless package_manifest('cluster-kube-descheduler-operator').exists?
      step %Q/cluster-kube-descheduler-operator catalog source name is stored in the :kdo_catsrc clipboard/
      step %Q/I use the "openshift-kube-descheduler-operator" project/
      # create subscription in `openshift-kube-descheduler-operator` namespace:
      sub_kube_descheduler_yaml ||= "#{BushSlicer::HOME}/testdata/descheduler/kd-sub-template.yaml"
      step %Q/I process and create:/, table(%{
        | f | #{sub_kube_descheduler_yaml} |
        | p | SOURCE=#{cb.kdo_catsrc}      |
        | p | CHANNEL=#{cb.kdo_channel}    |
      })
      raise "Error creating subscription for cluster_descheduler" unless @result[:success]
    end
  end
  # check csv existense
  csv = nil
  success = wait_for(300, interval: 10) {
    csv = subscription('cluster-kube-descheduler-operator').current_csv
    !(csv.nil?) && cluster_service_version(csv).exists?
  }
  raise "CSV #{csv} isn't created" unless success
  step %Q/cluster descheduler operator is ready/
end

Given /^cluster descheduler operator is ready$/ do
  ensure_admin_tagged
  step %Q/I use the "openshift-kube-descheduler-operator" project/
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=descheduler-operator |
  })
end

# upgrade operator and check the descheduler pods status
Given /^I upgrade the descheduler operator with:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  subscription = opts[:subscription]
  channel = opts[:channel]
  catsrc = opts[:catsrc]
  namespace = opts[:namespace]
  step %Q/I use the "#{namespace}" project/

  pre_csv = subscription(subscription).current_csv
  # upgrade operator
  patch_json = {"spec": {"channel": "#{channel}", "source": "#{catsrc}"}}
  patch_opts = {resource: "subscription", resource_name: subscription, p: patch_json.to_json, n: namespace, type: "merge"}
  @result = admin.cli_exec(:patch, **patch_opts)
  raise "Patch failed with #{@result[:response]}" unless @result[:success]
  # wait till new csv to be installed
  success = wait_for(180, interval: 10) {
    if channel != "stable"
      (subscription(subscription).installplan_csv.include? channel) || (subscription(subscription).installplan_csv.include? (channel.split('-')[1]))
    else
      subscription(subscription).installplan_csv != pre_csv
    end
  }
  raise "the new CSV can't be installed" unless success
  # wait till new csv is ready
  success = wait_for(600, interval: 10) {
    new_csv = subscription(subscription).current_csv(cached: false)
    cluster_service_version(new_csv).ready?[:success]
  }
  raise "can't upgrade operator #{subscription}" unless success
end

# only check the major version, such as 4.4, 4.5, 4.6, don't care about versions like 4.6.0-2020xxxxxxxx
Given /^I make sure the descheduler operator gets updated successfully if needed$/ do
  step %Q/I switch to cluster admin pseudo user/
  # check if channel name in subscription is same to the target channel
  step %Q/cluster-kube-descheduler-operator channel name is stored in the :kdo_channel clipboard/
  step %Q/cluster-kube-descheduler-operator catalog source name is stored in the :kdo_catsrc clipboard/
  # check DO
  step %Q/I use the "openshift-kube-descheduler-operator" project/
  kdo_current_channel = subscription("cluster-kube-descheduler-operator").channel(cached: false)
  kdo_current_catsrc = subscription("cluster-kube-descheduler-operator").source
  if cb.kdo_channel != kdo_current_channel || cb.kdo_catsrc != kdo_current_catsrc
    upgrade_kdo = true
    step %Q/I upgrade the descheduler operator with:/, table(%{
      | namespace    | openshift-kube-descheduler-operator |
      | subscription | cluster-kube-descheduler-operator   |
      | channel      | #{cb.kdo_channel}                   |
      | catsrc       | #{cb.kdo_catsrc}                    |
    })
    step %Q/the step should succeed/
  else
    upgrade_kdo = false
  end
end
