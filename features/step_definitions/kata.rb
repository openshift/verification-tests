Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  kata_ns ||= "openshift-sandboxed-containers-operator"
  kata_config_name = "example-kataconfig"
  step %Q/I switch to cluster admin pseudo user/
  unless namespace(kata_ns).exists?
    step %Q/the kata-operator is installed using OLM CLI/
  else
    logger.info("Checking for kata-operator existence...")
    project(kata_ns)
    step %Q/a pod is present with labels:/, table(%{
      | control-plane=controller-manager |
    })
    logger.info("Checking for kataconfig...")
    unless kata_config('example-kataconfig').exists?
      step %Q/I store master major version in the :master_version clipboard/
      step %Q|I obtain test data file "kata/release-#{cb.master_version}/kataconfiguration_v1_kataconfig.yaml"|
      @result = user.cli_exec(:apply, f: 'kataconfiguration_v1_kataconfig.yaml')
      raise "Failed to apply kataconfig" unless @result[:success]
      step %Q/I wait until number of completed kata runtime nodes match for "#{kata_config_name}"/
    end
  end
end

Given /^I wait for #{QUOTED} (uninstall|install) to start$/ do | kc_name, mode |
  timeout = 50
  stats = {}
  success = false
  wait_for(timeout, stats: stats) do
    if mode == 'install'
      success = kata_config(kc_name).installing?(user: user, quiet: true, cached: false)
    else
      success = kata_config(kc_name).uninstalling?(user: user, quiet: true, cached: false)
    end
    break if success
  end
  unless success
    raise "#{mode} failed to start after #{timeout} seconds"
  else
    logger.info("#{mode} started...")
  end
end

Given /^I wait until number of completed kata runtime nodes match#{OPT_QUOTED} for #{QUOTED}$/ do |number, kc_name|
  ready_timeout = 900
  matched = kata_config(kc_name).wait_till_installed_counter_match(
    user: user, seconds: ready_timeout)
  unless matched[:success]
    installed_node_count = kata_config(kc_name).install_completed_node_count(user: user, cached: false)
    expected_node_count = kata_config(kc_name).total_nodes_count
    raise "Kata runtime did not install into all worker nodes, only #{installed_node_count} reached, expecting #{expected_node_count}"
  end
end

Given /^I remove kata operator from the#{OPT_QUOTED} namespace$/ do | kata_ns |
  ensure_admin_tagged
  step %Q/I store master major version in the clipboard/
  kata_ns ||= "openshift-sandboxed-containers-operator"
  step %Q/I switch to cluster admin pseudo user/
  # 1. remove kataconfig first
  project(kata_ns)
  kataconfig_name = BushSlicer::KataConfig.list(user: admin).first.name
  step %Q/I ensure "#{kataconfig_name}" kata_config is deleted within 900 seconds/
  # 2. remove namespace
  step %Q/I ensure "#{kata_ns}" project is deleted/
end

# assumption is that kata is already installed
And /^I verify kata container runtime is installed into a worker node$/ do
  # create a project and install sample app has
  org_user = user
  step %Q/I switch to the first user/
  step %Q/I create a new project/
  cb.test_project_name = project.name
  file_path = "kata/example-fedora-kata.yaml"
  step %Q(I run oc create over ERB test file: #{file_path})
  raise "Example kata pod creation failed" unless @result[:success]
  logger.info("Waiting for 'example-fedora-kata' pod to be RUNNING")
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=example-fedora-kata-app |
  })
  logger.info("Checking for runtime engine match...")
  # 1. check pod's spec to make sure the runtimeClassName is 'kata'
  pod_runtime_class_name = pod('example-fedora-kata').raw_resource['spec']['runtimeClassName']
  if pod_runtime_class_name != 'kata'
    raise "Pod's runtimeclass name #{pod_runtime_class_name} should be `kata`"
  end

  logger.info("Checking for running process `qemu` with the pod...")
  # 2. check there's a process with the pod name `qemu`
  step %Q/I switch to cluster admin pseudo user/
  node_cmd = "ps aux | grep qemu"
  @result = node(pod.node_name).host.exec_admin(node_cmd)
  raise "No qemu process detected inside pod node" unless @result[:response].include? 'qemu'
end

Given /^there is a catalogsource for kata container$/ do
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-marketplace" project/
  step %Q|I obtain test data file "kata/catalogsource.yaml"|
  user.cli_exec(:apply, f: 'catalogsource.yaml')
  step %Q/a pod becomes ready with labels:/, table(%{
    | olm.catalogSource=redhat-marketplace |
  })
end

Given /^the kata-operator is installed(?: to #{OPT_QUOTED})? using OLM(?: (CLI|GUI))?$/ do | kata_ns, install_method |
  ensure_admin_tagged
  kata_ns ||= "openshift-sandboxed-containers-operator"
  kata_config_name = "example-kataconfig"
  step %Q/I store master major version in the :master_version clipboard/
  raise "Kata operator OLM installation only supported for OCP >= 4.8" unless cb.master_version >= "4.8"
  install_method ||= 'CLI'

  unless kata_config(kata_config_name).exists?
    if install_method == 'GUI'
      package_name = 'kata-operator'
      catalog_name = 'qe-app-registry'

      @result = admin.cli_exec(:create_namespace, name: kata_ns)
      project(kata_ns)
      step %Q/I switch to the first user/
      step %Q/the first user is cluster-admin/
      step %Q(I use the "#{kata_ns}" project)
      step %Q/I open admin console in a browser/
      step %Q/the step should succeed/
      step %Q/I perform the :goto_operator_subscription_page web action with:/, table(%{
        | package_name     | #{package_name} |
        | catalog_name     | #{catalog_name} |
        | target_namespace | #{kata_ns}      |
      })
      step %Q/the step should succeed/
      # save the channel from subscription into cb.channel
      step %Q/I extract the channel information from subscription and save it to the clipboard/
      step %Q/I perform the :set_custom_channel_and_subscribe web action with:/, table(%{
        | update_channel    | #{cb.channel} |
        | install_mode      | OwnNamespace  |
        | approval_strategy | Automatic     |
      })
      step %Q/the step should succeed/
      step %Q/a pod becomes ready with labels:/, table(%{
        | control-plane=controller-manager |
      })
    else
      step %Q/I switch to cluster admin pseudo user/
      step %Q|I obtain test data file "kata/release-#{cb.master_version}/deployment.yaml"|
      @result = user.cli_exec(:apply, f: "deployment.yaml")
      raise "Failed to deploy kata operator" unless @result[:success]
      project(kata_ns)
    end

    # make sure kata-operator is running first before installing the kataconfig
    step %Q/a pod is present with labels:/, table(%{
      | control-plane=controller-manager |
    })
    step %Q|I obtain test data file "kata/release-#{cb.master_version}/kataconfiguration_v1_kataconfig.yaml"|
    @result = user.cli_exec(:apply, f: 'kataconfiguration_v1_kataconfig.yaml')
    raise "Failed to apply kataconfig" unless @result[:success]
    step %Q/I wait for "#{kata_config_name}" install to start/
  else
    logger.info("There's already an existing 'kataconfig' resuing it...")
    project(kata_ns)
    step %Q/I switch to cluster admin pseudo user/
  end
  step %Q/I wait until number of completed kata runtime nodes match for "#{kata_config_name}"/
end

Given /^I extract the channel information from subscription and save it to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :channel
  step %Q/I store master major version in the :master_version clipboard/ if cb.master_version.nil?
  step %Q|I obtain test data file "kata/release-#{cb.master_version}/subscription.yaml"|
  channel = YAML.load(open('subscription.yaml')).dig('spec', 'channel')
  logger.info("Subscription using channel: #{channel}")
  cb[cb_name] = channel
end
