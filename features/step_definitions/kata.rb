Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  transform binding, :ns
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
  transform binding, :number, :kc_name
  ready_timeout = 900
  matched = kata_config(kc_name).wait_till_installed_counter_match(
    user: user, seconds: ready_timeout, count: number.to_i)
  unless matched[:success]
    raise "Kata runtime did not install into all worker nodes!"
  end
end

Given /^I remove kata operator from #{QUOTED} namespace$/ do | kata_ns |
  transform binding, :kata_ns
  # 1. remove kataconfig first
  project(kata_ns)
  kataconfig_name = BushSlicer::KataConfig.list(user: admin).first.name
  step %Q/I ensure "#{kataconfig_name}" kata_config is deleted/
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
