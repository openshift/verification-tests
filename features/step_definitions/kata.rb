Given /^I wait until number of completed kata runtime nodes for #{QUOTED} matches$/ do |kc_name|
  ready_timeout = 1200
  matched = kata_config(kc_name).wait_till_installed_counter_match(
    user: user, seconds: ready_timeout)
  installed_node_count = kata_config(kc_name).install_completed_node_count(user: user, cached: false)
  expected_node_count = kata_config(kc_name).total_nodes_count
  raise "Kata runtime did not install into all worker nodes, only #{installed_node_count} reached, expecting #{expected_node_count}" unless matched[:success]
  logger.info("#{installed_node_count} out of #{expected_node_count} worker nodes installed with kata runtime")
end

Given /^valid cluster type for kata tests exists$/ do
  accepted_platforms = ['gcp', 'azure']
  iaas_type = env.iaas[:type] rescue nil
  raise "Kata installation only supports #{accepted_platforms} platforms, #{iaas_type} is not a valid cluster type" unless accepted_platforms.include? iaas_type
  logger.info("Cluster type #{iaas_type.to_s.upcase} is a valid cluster type")
end

Given /^catalogsource #{QUOTED} exists in #{QUOTED} namespace$/ do |catalog_source_name, project_name|
  step %Q/I switch to cluster admin pseudo user/
  project(project_name)
  raise "Failed to create catalog source" unless catalog_source("#{catalog_source_name}").exists?
  logger.info("Catalog source #{catalog_source_name} exists")
end

When /^I install sandboxed-operator in #{QUOTED} namespace$/ do |kata_ns|
  step %Q/I store master major version in the :master_version clipboard/
  step %Q/I switch to cluster admin pseudo user/
  step %Q|I obtain test data file "kata/namespace.yaml"|
  @result_namespace = user.cli_exec(:apply, f: "namespace.yaml")
  raise "Failed to install sandboxed-operator" unless @result_namespace[:success]
  step %Q|I obtain test data file "kata/operatorgroup.yaml"|
  @result_operatorgroup = user.cli_exec(:apply, f: "operatorgroup.yaml")
  raise "Failed to install sandboxed-operator" unless @result_operatorgroup[:success]
  step %Q|I obtain test data file "kata/policy.yaml"|
  @result_policy = user.cli_exec(:apply, f: "policy.yaml")
  raise "Failed to install sandboxed-operator" unless @result_policy[:success]
  step %Q|I obtain test data file "kata/catalogsource.yaml"|
  @result_catalog = user.cli_exec(:apply, f: "catalogsource.yaml")
  raise "Failed to install sandboxed-operator" unless @result_catalog[:success]
  step %Q|I obtain test data file "kata/subscription.yaml"|
  @result_subcription = user.cli_exec(:apply, f: "subscription.yaml")
  raise "Failed to install sandboxed-operator" unless @result_subcription[:success]
end

Then /^sandboxed-operator operator should be installed and running$/ do
  step %Q/I wait until sandboxed operator is ready/
end

Given /^I wait until sandboxed operator is ready$/ do
  timeout = 120
  kata_ns = "openshift-sandboxed-containers-operator"
  expected_status = "Installed"
  expected_state = "Succeeded"
  operator_status = {
    instruction: "Wait till operator is installed to all worker nodes",
    success: false,
  }
  operator_status[:success] = wait_for(timeout, stats: {}) do
    step %Q/I store master major version in the :master_version clipboard/
    if cb.master_version == "4.9"
      @result_status = admin.cli_exec(:get, resource: "operators", o: "jsonpath=''{..status.components.refs[4].conditions[0].type}'", n:kata_ns)[:stdout].to_s.include? expected_status
      @result_state = admin.cli_exec(:get, resource: "operators", o: "jsonpath=''{..status.components.refs[5].conditions[0].type}'", n:kata_ns)[:stdout].to_s.include? expected_state
    else
      @result_status = admin.cli_exec(:get, resource: "operators", o: "jsonpath=''{..status.components.refs[7].conditions[0].type}'", n:kata_ns)[:stdout].to_s.include? expected_status
      @result_state = admin.cli_exec(:get, resource: "operators", o: "jsonpath=''{..status.components.refs[8].conditions[0].type}'", n:kata_ns)[:stdout].to_s.include? expected_state
    end
  end
  raise "Failed to install sandboxed operator" unless @result_state
  logger.info("Sandboxed operator installation status is #{expected_state}")
end

When /^I apply #{QUOTED} in #{QUOTED} namespace$/ do |kata_config_name, kata_ns|
  step %Q/I store master major version in the :master_version clipboard/
  step %Q|I obtain test data file "kata/release-#{cb.master_version}/kataconfiguration_v1_kataconfig.yaml"|
  @result = user.cli_exec(:apply, f: 'kataconfiguration_v1_kataconfig.yaml', n:kata_ns)
  raise "Failed to apply #{kata_config_name} kataconfig" unless @result[:success]
end

Then /^Kata runtime installed on selected worker nodes for #{QUOTED} kataconfig$/ do |kataconfig_name|
  step %Q|I wait until number of completed kata runtime nodes for "#{kataconfig_name}" matches|
end

When /^I apply #{QUOTED} pod in #{QUOTED} namespace$/ do |pod_name, kata_ns|
  step %Q|I obtain test data file "kata/#{pod_name}.yaml"|
  @result = user.cli_exec(:apply, f: "#{pod_name}.yaml", n:kata_ns)
  raise "Failed to deploy a pod" unless @result[:success]
end

Then /^#{QUOTED} pod should run using kata runtime$/ do |pod_name|
  step %Q|I wait until "#{pod_name}" is ready|
end

Given /^I wait until #{QUOTED} pod is running$/ do |pod_name|
  timeout = 30
  kata_ns = "openshift-sandboxed-containers-operator"
  expected_status = "Running"
  pod_status = {
    instruction: "Wait till pod is running",
    success: false,
  }
  pod_status[:success] = wait_for(timeout) do
    @result_status = admin.cli_exec(:get, resource: "pods/#{pod_name}", o: "jsonpath=''{..status.phase}'", n:kata_ns)[:stdout].to_s.include? expected_status
  end
  raise "Failed to deploy a pod" unless @result_status
  logger.info("Pod deployment status is #{expected_status}")
end

Given /^I check if #{QUOTED} runtime is kata$/ do |pod_name|
  timeout = 30
  kata_ns = "openshift-sandboxed-containers-operator"
  expected_runtime = "kata"
  pod_status = {
    instruction: "Check if pod runtime is kata",
    success: false,
  }
  pod_status[:success] = wait_for(timeout) do
    @result_runtime = admin.cli_exec(:get, resource: "pods/#{pod_name}", o: "jsonpath=''{..spec.runtimeClassName}'", n:kata_ns)[:stdout].to_s.include? expected_runtime
  end
  raise "Pod's runtime it not kata" unless @result_runtime
  logger.info("Pod runtime is #{expected_runtime}")
end

Given  /^kata operator is installed successfully$/ do
  step %Q/catalogsource "redhat-operators" exists in "openshift-marketplace" namespace/
  step %Q/I install sandboxed-operator in "openshift-sandboxed-containers-operator" namespace/
  step %Q/sandboxed-operator operator should be installed and running/
end
