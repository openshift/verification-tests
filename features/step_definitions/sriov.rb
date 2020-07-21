Given /^the sriov operator is running well$/ do
  ensure_destructive_tagged
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/evaluation of `cluster_version('version').channel.split('-')[1]` is stored in the :ocp_cluster_version clipboard/

  unless project('openshift-sriov-network-operator').exists?
    if cb.ocp_cluster_version.include? "4.[34]."
      # create 4.3/4.4 namespaces
      step %Q{I obtain test data file "networking/sriov/namespace/43/ns.yaml"}
      @result = admin.cli_exec(:create, f: "ns.yaml")
      raise "Error creating namespace for openshift-sriov-network-operator" unless @result[:success]
    else
      # Create namespace for 4.5 and later
      step %Q{I obtain test data file "networking/sriov/namespace/45/ns45.yaml"}
      @result = admin.cli_exec(:create, f: "ns45.yaml")
      raise "Error creating namespace for openshift-sriov-network-operator" unless @result[:success]
    end
    
  end
  step %Q/I use the "openshift-sriov-network-operator" project/
  unless operator_group('sriov-network-operators').exists?
    step %Q{I obtain test data file "networking/sriov/og/og.yaml"}
    @result = admin.cli_exec(:create, f: "og.yaml")
    raise "Error creating og for openshift-sriov-network-operator" unless @result[:success]
  end
  
  unless subscription('sriov-network-operator-subsription').exists?
     step %Q{I obtain test data file "networking/sriov/subscription/sub.yaml"}
     step %Q/I process and create:/, table(%{
          | f | sub.yaml                           |
          | p | CHANNEL=#{cb.ocp_cluster_version}  |
     })
     raise "Error creating subscription for sriov operator" unless @result[:success]
  end
  
  step %Q/sriov operator is ready/
  step %Q/sriov config daemon is ready/
end

Given /^sriov operator is ready$/ do
  ensure_admin_tagged
  project("openshift-sriov-network-operator")
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=sriov-network-operator |
  })
end

Given /^sriov config daemon is ready$/ do
  ensure_admin_tagged
  project("openshift-sriov-network-operator")
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=sriov-network-config-daemon |
  })
end

Given /^I create sriov resource with following:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-sriov-network-operator" project/
  sriov_ns = "openshift-sriov-network-operator"
  resource_yaml = opts[:cr_yaml]
  cr_name = opts[:cr_name]
  resource_type = opts[:resource_type]
  logger.info("resource type is: #{resource_type}")
  case resource_type
  when "sriovnetworknodepolicies"
    logger.info("resource type is: sriovnetworknodepolicies")
    if sriov_network_node_policy(cr_name).exists?
       step %Q/I delete the "#{cr_name}" sriov networkpolicy/
    end

    @result = admin.cli_exec(:create, f: resource_yaml, n: sriov_ns)
    raise "Unable to create sriov policy" unless @result[:success]
    teardown_add {
      step %Q/I delete the "#{cr_name}" sriov networkpolicy/
    }
  when "sriovnetwork"
    cr_project = opts[:project]
    logger.info("resource type is: sriovnetwork")
    if sriov_network(cr_name).exists?
       step %Q/I delete the "#{cr_name}" sriovnetwork/
    end

    #@result = admin.cli_exec(:create, f: resource_yaml, n: sriov_ns)
     step %Q/I process and create:/, table(%{
          | f | #{resource_yaml}      |
          | p | default=#{cr_project} |
     })
    
    raise "Unable to create sriovnetwork" unless @result[:success]
    teardown_add {
      step %Q/I delete the "#{cr_name}" sriovnetwork/
    }
  end 
end


Given /^I delete the #{QUOTED} sriov networkpolicy$/ do | cr_name |
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-sriov-network-operator" project/
  sriov_ns = "openshift-sriov-network-operator"
  if sriov_network_node_policy(cr_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'sriovnetworknodepolicies', object_name_or_id: cr_name, n: sriov_ns)
    raise "Unable to delete the sriov policy" unless @result[:success]
  end
end

Given /^I delete the #{QUOTED} sriovnetwork$/ do | cr_name |
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-sriov-network-operator" project/
  sriov_ns = "openshift-sriov-network-operator"
  if sriov_network(cr_name).exists?
    @result = admin.cli_exec(:delete, object_type: 'sriovnetwork', object_name_or_id: cr_name, n: sriov_ns)
    raise "Unable to delete the sriovnetwork" unless @result[:success]
  end
end
