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
  timeout = 300
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
  ready_timeout = 1200
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
  # prereq is that there are no outstanding pods in the cluster with
  # kata-runtime.  Do the destructive action of removing them so kataconfig can be removed.
  step %Q/I find all pods running with kata as runtime in the cluster and store them to the :kata_pods clipboard/
  if cb.kata_pods.count > 0
    logger.info("All existing pods using kata must be removed before kataconfig can be uninstalled.")
    logger.info("Removing all pods using kata...")
    step %Q/I remove all kata pods in the cluster stored in the clipboard/
  end

  kataconfig_name = BushSlicer::KataConfig.list(user: admin).first.name
  step %Q/I ensure "#{kataconfig_name}" kata_config is deleted within 1200 seconds/
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
  pod_runtime_class_name = pod('example-fedora-kata').runtime_class_name
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
  # first check pre-req
  step %Q/I switch to cluster admin pseudo user/
  project('openshift-marketplace')
  unless catalog_source('qe-app-registry').exists?
    logger.info("Kata installation depends on `qe-app-registry`, which is missing in this cluster, calling step to create it...")
    step %Q/I create "qe-app-registry" catalogsource for testing/
  end

  unless kata_config(kata_config_name).exists?
    if install_method == 'GUI'
      package_name = 'sandboxed-containers-operator'
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
    step %Q/a pod becomes ready with labels:/, table(%{
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
    # make sure kata-operator is running first before installing the kataconfig
    step %Q/a pod becomes ready with labels:/, table(%{
      | control-plane=controller-manager |
    })
  end
  logger.info("Using kata image: #{pod.container_specs.first.image}")
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

Given /^I find all pods running with kata as runtime in the cluster and store them to the#{OPT_SYM} clipboard$/ do |cb_name|
  ensure_admin_tagged
  cb_name ||= :kata_pods
  @result_pods = admin.cli_exec(:get, resource: "pods", all_namespaces: true, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")
  @result_namespaces = admin.cli_exec(:get, resource: "pods", all_namespaces: true, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.namespace}'")
  pods = eval(@result_pods[:response]).split(' ')
  ns = eval(@result_namespaces[:response]).split(' ')
  ns_pods_list = ns.zip pods
  kata_pods = []
  ns_pods_list.each do |ns, p|
    project(ns)
    pod_obj = pod(p)
    kata_pods << pod_obj
  end
  cb[cb_name] = kata_pods
end

Given /^I remove all kata pods in the cluster stored in the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :kata_pods
  cb[cb_name].each do | kp |
    logger.info("Removing pod #{kp.name}...")
    begin
      res_type, res_name = kp.walk_owner_references(user: user, resource_name: pod.name, resource_type: kp)
      unless res_type.is_a? String
        res_type = res_type.class.name.split('BushSlicer::').last
      end
      resource_word = camel_to_snake_case(res_type) # BushSlicer::RESOURCES[res_type.class].to_s
      step_sentence = "I ensure \"#{res_name}\" #{resource_word} is deleted from the \"#{project.name}\" project"
      step %Q/#{step_sentence}/
    rescue
      next
    end
  end
end

Given /^I run must-gather command$/ do
  require 'json'
  command = 'quay.io/openshift_sandboxed_containers/openshift-sandboxed-containers-must-gather:202106221012'
  logger.info("==================================TEST IS RUNNING=========================================")
  logger.info("Running must-gather command")
  @result = env.admin.cli_exec(:oadm_must_gather, image:command)
  pods_json = ''
  @error_message = {}
  dc_output = @result[:stdout]
  @crio_logs_counter = 0
  @audit_logs_counter = 0
  logger.info("\nMust-gather image is:#{command}")
  if dc_output.to_s.include? "logs_crio"
    logger.info("CRI-O logs are in must-gather bundle")
    dc_output.each_line do |line|
      if line.to_s.include? "logs_crio"
        #logger.info(line)
        @crio_logs_counter += 1
      end
    end
  end
  logger.info("There are #{@crio_logs_counter} CRI-O logs in must-gather bundle")
  logger.info("#{@crio_logs_counter} CRI-O logs matches 6 node cluster")
  if dc_output.to_s.include? "audit.log"
    logger.info("Audit logs are in must-gather bundle")
    dc_output.each_line do |line|
      if line.to_s.include? "audit.log"
        #logger.info(line)
        @audit_logs_counter += 1
      end
    end
  end
  logger.info("There are #{@audit_logs_counter} Audit logs in must-gather bundle")
  logger.info("#{@audit_logs_counter} Audit logs matches 3 audit logs for every worker node")
  raise "Failed to run must-gather command" unless @result[:success]
end

Given /^Pre-test checks$/ do
  require 'json'
  #require '/home/valiev/mygit/verification-tests/lib/world'
  #require '/home/valiev/mygit/verification-tests/features/step_definitions/cluster'
  kata_ns ||= "openshift-sandboxed-containers-operator"
  kata_config_name = "example-kataconfig"
  project(kata_ns)
  namespace_exists = namespace(kata_ns).exists?
  kataconfig_exists = kata_config('example-kataconfig').exists?
  @result_pods = admin.cli_exec(:get, resource: "pods", n:kata_ns, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")
  #@pods_json = @result_pods[:stdout]
  @error_message = {}
  node_cmd = "cat /proc/sys/crypto/fips_enabled"
  #@randomWorkerNodeName = ""
  @version = admin.cli_exec(:get, resource: "clusterversion", n:kata_ns, o: "jsonpath='{.items[0].status.history[0].version}'")
  @datajs = admin.cli_exec(:get, resource: "nodes", n:kata_ns, o: "json")
  @data = JSON.parse(@datajs[:stdout])
  @nodeAmmount = @data['items'].count
  @workerNodesAmmount = 0
  @masterNodesAmmount = 0
  @data['items'].each do |node|
    if node['metadata']['name'].include? 'master'
      @masterNodesAmmount += 1
    else
      #@randomWorkerNodeName = node['metadata']['name']
      @workerNodesAmmount += 1
    end
  end
  @fips_status = node('valiev-kata-49-demo-8lhcq-worker-a-sjz94').host.exec_admin(node_cmd)
  logger.info("Cluster version is:#{@result_pods[:stdout]}")
  logger.info("==================================RUNNING PRE-TEST CHECKS=========================================")
  logger.info("Cluster version is:#{@version[:stdout]}")
  logger.info("Total ammount of nodes:#{@nodeAmmount}")
  logger.info("Total ammount of worker nodes:#{@workerNodesAmmount}")
  logger.info("Total ammount of master nodes:#{@masterNodesAmmount}")
  #logger.info("Nodes:#{@nodes}")
  if namespace_exists
    logger.info("Sandboxed operator namespace exists")
  else
    @error_message['Namespace_message'] = "Sandboxed operator namespace doesn't exists"
  end
  if kataconfig_exists
    logger.info("Sandboxed operator kataconfig exists")
  else
    @error_message['Kataconfig_message'] = "Sandboxed operator kataconfig doesn't exists"
  end
  if @result_pods[:stdout].to_s.include? "''"
    @error_message['Kata pods_message'] = "No pods with kata runtime"
  else
    logger.info("At least 1 pod with kata runtime exists")
  end
  if @fips_status[:stdout].to_s.include? "0"
    logger.info("FIPS is disabled")
  else
    logger.info("FIPS is enabled")
  end
  if namespace_exists && kataconfig_exists && (!@result_pods[:stdout].to_s.include? "''")
    logger.info("Sandboxed operator installed")
    logger.info("Pre-test checks passed, test can start")
  else
    logger.error("====================================PRE-TEST CHECKS FAILED===========================================\n")
    @error_message.each do |name, message|
      logger.error("#{name}:#{message}")
    end
    logger.error("Pre test checks failed, can't start the test\n")
    break
  end
end

Given /^Verify catalog source existence$/ do
  project_name = 'openshift-marketplace'
  catalog_source_name = 'qe-app-registry'
  step %Q/I switch to cluster admin pseudo user/
  project(project_name)
  if !catalog_source(catalog_source_name).exists?
    logger.warn("Missing #{catalog_source_name} catalog source")
    logger.info("Creating #{catalog_source_name}")
    step %Q/I create "qe-app-registry" catalogsource for testing/
    sleep(120)
    #raise "Failed to create catalog source" unless catalog_source('qe-app-registry').exists?
  elsif catalog_source('qe-app-registry').exists?
    logger.info("Catalog source #{catalog_source_name} exists")
  end
end

Given /^Install Kata operator$/ do
  kata_ns ||= "openshift-sandboxed-containers-operator"
  kata_operator_name = "sandboxed-containers-operator"
  @result_operators = admin.cli_exec(:get, resource: "operators", n:kata_ns)
  if !@result_operators[:stdout].to_s.include? kata_operator_name
    project(kata_ns)
    step %Q/I store master major version in the :master_version clipboard/
    logger.warn("#{kata_operator_name} is not installed")
    logger.info("Installing #{kata_operator_name}")
    step %Q/I switch to cluster admin pseudo user/
    step %Q|I obtain test data file "kata/release-#{cb.master_version}/deployment.yaml"|
    @result = user.cli_exec(:apply, f: "deployment.yaml")
    sleep(120)
    #raise "Failed to deploy kata operator" unless !@result[:stderr].to_s.empty?
    project(kata_ns)
    @result_operators = admin.cli_exec(:get, resource: "operators", n:kata_ns)
  elsif @result_operators[:stdout].to_s.include? kata_operator_name
    logger.info("#{kata_operator_name} exists")
  end
end

Given /^Apply #{QUOTED} kataconfig$/ do |kata_config_name|
  kata_ns ||= "openshift-sandboxed-containers-operator"
  #kata_config_name = "example-kataconfig"
  project(kata_ns)
  step %Q/I store master major version in the :master_version clipboard/
  @result_kataconfigs = admin.cli_exec(:get, resource: "kataconfig", n:kata_ns)
  if @result_kataconfigs[:stderr].to_s.include? "No resources found"
    step %Q/I store master major version in the :master_version clipboard/
    step %Q|I obtain test data file "kata/release-#{cb.master_version}/kataconfiguration_v1_kataconfig.yaml"|
    @result = user.cli_exec(:apply, f: 'kataconfiguration_v1_kataconfig.yaml')
    sleep(60)
    #raise "Failed to apply kataconfig" unless @result[:success]
    step %Q/I wait until number of completed kata runtime nodes match for "#{kata_config_name}"/
  end
end


Given /^Deploy #{QUOTED} pod with kata runtime$/ do |pod_name|
  #Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  kata_ns ||= "openshift-sandboxed-containers-operator"
  file_path = "kata/#{pod_name}.yaml"
  pod_runtime = "kata"
  project(kata_ns)
  step %Q/I switch to cluster admin pseudo user/
  @result_pods = admin.cli_exec(:get, resource: "pods", n:kata_ns, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")
  logger.info("Installing #{pod_name}")
  if @result_pods[:stdout].to_s.include? "''"
    logger.warn("No pods with kata runtime")
    logger.info("Deploying #{pod_name} pod with kata runtime")
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I create a new project/
    cb.test_project_name = project.name
    #@deploy_pod = admin.cli_exec(:create, n:kata_ns, f: file_path)
    step %Q(I run oc create over ERB test file: #{file_path})
    sleep(60)
    #raise "Kata pod creation failed" unless @result[:success]
    logger.info("Waiting for RUNNING pod status")
    logger.info("Checking for runtime engine match...")
    @result_pods = admin.cli_exec(:get, resource: "pods", n:kata_ns, o: "jsonpath='{.items[?(@.spec.runtimeClassName==\"kata\")].metadata.name}'")
    #raise "Failed to deploy #{pod_name}" unless !@result_pods[:stdout].to_s.include? "''"
  else
    logger.info("List of pods with kata runtime:\n #{@result_pods[:stdout]}")
  end
end

Given /^Apply #{QUOTED} test setup$/ do |setupLevel|
        #setupLevel = "full"
        require '/home/valiev/mygit/verification-tests/features/kata/test_constants'
        require '/home/valiev/mygit/verification-tests/features/kata/test_functions/cluster'
        require '/home/valiev/mygit/verification-tests/features/kata/objects/cluster'
        clusterObj = ClusterObj.new()
        result = true
        if setupLevel.to_s.include? SETUP_OPTIONS
                if setupLevel.to_s.equal? 'full'
                        result = fullPreTestChecks(clusterObj)
                elsif setupLevel.to_s.equal? 'kataconfig'
                        result = checkForKataconfigExistance(clusterObj)
                elsif setupLevel.to_s.equal? 'operator'
                        result = checkForKataconfigExistance(clusterObj)
                elsif setupLevel.to_s.equal? 'operator'
                        result = checkForPodRuntime('example')
                end
        else
            	result = false
                logger.error("#{setupLevel} is not a valid option for test setup")
                logger.error("Valid options are #{SETUP_OPTIONS}")
        end
	if result
                logger.info("Pre-test checks passed, test can start")
        else
            	logger.error("Pre test checks failed, can't start the test\n")
        break
	end
end

