Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  kata_ns ||= "kata-operator"
  step %Q/I switch to cluster admin pseudo user/
  unless namespace(kata_ns).exists?
    @result = user.cli_exec(:create_namespace, name: kata_ns)
    raise "Failed to create namespace #{kata_ns}" unless @result[:success]
  end
  step %Q/I store master major version in the :master_version clipboard/
  project(kata_ns)
  iaas_type = env.iaas[:type] rescue nil
  accepted_platforms = ['gcp', 'azure']
  raise "Kata installation only supports GCE platform currently." unless accepted_platforms.include? iaas_type
  # check to see if kata already exists
  unless kata_config('example-kataconfig').exists?
    # setup service account
    role_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/role.yaml"
    role_binding_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/role_binding.yaml"
    sa_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/service_account.yaml"
    kataconfigs_crd_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/crds/kataconfiguration.openshift.io_kataconfigs_crd.yaml"
    kata_operator_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/operator.yaml"
    @result = user.cli_exec(:apply, f: role_yaml)
    @result = user.cli_exec(:apply, f: role_binding_yaml)
    @result = user.cli_exec(:apply, f: sa_yaml)
    step %Q/SCC "privileged" is added to the "#{ns}" service account without teardown/
    # step %Q/ give project privileged role to the kata-operator service account/
    # create a custom resource to install the Kata Runtime on all workers
    @result = user.cli_exec(:apply, f: kataconfigs_crd_yaml)
    #raise "Error when creating kataconfig_crd." unless $result[:success]
    @result = user.cli_exec(:create, f: kata_operator_yaml)
    #raise "Error when creating kata operator." unless $esult[:success]
    step %Q/a pod becomes ready with labels:/, table(%{
      | name=kata-operator |
    })
    # install the Kata Runtime on all workers
    kataconfig_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/crds/kataconfiguration.openshift.io_v1alpha1_kataconfig_cr.yaml"
    @result = user.cli_exec(:apply, f: kataconfig_yaml)
    raise "Failed to apply kataconfig" unless @result[:success]
    step %Q/I store all worker nodes to the :nodes clipboard/
    step %Q/I wait until number of completed kata runtime nodes match "<%= cb.nodes.count %>" for "example-kataconfig"/
  end
end


Given /^I wait until number of completed kata runtime nodes match #{QUOTED} for #{QUOTED}$/ do |number, kc_name|
  ready_timeout = 900
  matched = kata_config(kc_name).wait_till_installed_counter_match(
    user: user, seconds: ready_timeout, count: number.to_i)
  unless matched[:success]
    raise "Kata runtime did not install into all worker nodes!"
  end
end

Given /^I remove kata operator from the#{OPT_QUOTED} namespace$/ do | kata_ns |
  ensure_admin_tagged
  step %Q/I store master major version in the clipboard/
  if kata_ns.nil?
    if cb.master_version == '4.6'
      kata_ns = "kata-operator"
    elsif cb.master_version == '4.7'
      kata_ns = "kata-operator-system"
    else
      kata_ns = "sandboxed-containers-operator-system"
    end
  end
  step %Q/I switch to cluster admin pseudo user/
  # 1. remove kataconfig first
  project(kata_ns)
  kataconfig_name = BushSlicer::KataConfig.list(user: admin).first.name
  step %Q/I ensure "#{kataconfig_name}" kata_config is deleted within 900 seconds/
  # 2. remove namespace
  step %Q/I ensure "#{kata_ns}" project is deleted/
end

# # assumption that
And /^I verify kata container runtime is installed into the a worker node$/ do
  # create a project and install sample app has
  org_user = user
  step %Q/I switch to the first user/
  step %Q/I create a new project/
  cb.test_project_name = project.name
  file_path = "kata/release-#{cb.master_version}/example-fedora.yaml"
  step %Q(I run oc create over ERB test file: #{file_path})
  raise "Example kata pod creation failed" unless @result[:success]

  # 1. check pod's spec to make sure the runtimeClassName is 'kata'
  pod_runtime_class_name = pod('example-fedora').raw_resource['spec']['runtimeClassName']
  if pod_runtime_class_name != 'kata'
    raise "Pod's runtimeclass name #{pod_runtime_class_name} should be `kata`"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=example-kata-fedora-app |
  })
  # 2. check there's a process with the pod name `qemu`
  step %Q/I switch to cluster admin pseudo user/
  node_cmd = "ps aux | grep qemu"
  @result = node(pod.node_name).host.exec_admin(node_cmd)
  raise "No qemu process detected inside pod node" unless @result[:response].include? 'qemu'
end

Given /^there is a catalogsource for kata container$/ do
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-marketplace" project/
  step %Q|I obtain test data file "kata/release-4.7/catalogsource.yaml"|
  user.cli_exec(:apply, f: 'catalogsource.yaml')
  step %Q/a pod becomes ready with labels:/, table(%{
    | olm.catalogSource=redhat-marketplace |
  })
end

Given /^the kata-operator is installed(?: to #{OPT_QUOTED})? using OLM(?: (CLI|GUI))?$/ do | kata_ns, install_method |
  ensure_admin_tagged
  kata_ns ||= "kata-operator-system"
  cluster_ver = cluster_version('version').version.split('-').first.to_f
  kata_ns = "sandboxed-containers-operator-system" if cluster_ver >= 4.8
  install_method ||= 'CLI'
  if install_method == 'GUI'
    package_name = 'kata-operator'
    if cluster_ver >= 4.8
      catalog_name = 'qe-app-registry'
    else
      catalog_name = 'kataconfig-catalog'
    end
    step %Q/there is a catalogsource for kata container/ if cluster_ver < 4.8
    @result = admin.cli_exec(:create_namespace, name: kata_ns)
    project(kata_ns)
    #step %Q/I use the "#{kata_ns}" project/
    # step %Q/I switch to cluster admin pseudo user/
    step %Q/I switch to the first user/
    step %Q/the first user is cluster-admin/
    step %Q(I use the "#{kata_ns}" project)
    step %Q/evaluation of `cluster_version('version').version.split('-')[0].to_f` is stored in the :channel clipboard/
    step %Q/I open admin console in a browser/
    step %Q/the step should succeed/
    step %Q/I perform the :goto_operator_subscription_page web action with:/, table(%{
      | package_name     | #{package_name} |
      | catalog_name     | #{catalog_name} |
      | target_namespace | #{kata_ns}      |
    })
    step %Q/the step should succeed/
    step %Q/I perform the :set_custom_channel_and_subscribe web action with:/, table(%{
      | update_channel    | #{cluster_ver} |
      | install_mode      | OwnNamespace   |
      | approval_strategy | Automatic      |
    })
    step %Q/the step should succeed/
    step %Q/a pod becomes ready with labels:/, table(%{
      | control-plane=controller-manager |
    })
  else
    step %Q/I switch to cluster admin pseudo user/
    step %Q|I obtain test data file "kata/release-4.7/deployment.yaml"|
    @result = user.cli_exec(:apply, f: "deployment.yaml")
    raise "Failed to apply kataconfig" unless @result[:success]
    project(kata_ns)
  end
  step %Q/SCC "privileged" is added to the "default" service account/ if cluster_ver < 4.8
  step %Q|I obtain test data file "kata/release-#{cluster_ver}/kataconfiguration_v1_kataconfig.yaml"|
  @result = user.cli_exec(:apply, f: 'kataconfiguration_v1_kataconfig.yaml')
  raise "Failed to apply kataconfig" unless @result[:success]
  step %Q/I store all worker nodes to the :nodes clipboard/
  step %Q/I wait until number of completed kata runtime nodes match "<%= cb.nodes.count %>" for "example-kataconfig"/
end
