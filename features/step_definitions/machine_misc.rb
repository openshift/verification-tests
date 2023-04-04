Given(/^thin sc or thin-csi sc is present as default$/) do 
  ensure_admin_tagged

  if env.version_lt("4.13", user: user)
    step %Q{I get project events}
    step %Q/the output should match:/,table(%{
      | Failed to provision volume with StorageClass "thin": Credentials not found |
    })
    step %Q{the step should succeed}
  else
    step %Q{I use the "openshift-cluster-csi-drivers" project}
    step %Q/I run the :get admin command with:/,table(%{
      | resource | pods |})
    step %Q{the step should succeed}
    step %Q/the output should contain:/,table(%{
      | CrashLoopBackOff |
    })
  end
end

Given(/I check the cluster platform is not None$/) do
  ensure_admin_tagged

  if infrastructure("cluster").platform == "None"
     logger.warn "When platform is None,machine-api-controllers are not present"
     logger.warn "We will skip this scenario"
     skip_this_scenario
  end
end

Given(/^the last provisioned machine is worker$/) do
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  puts machines.max_by(&:created_at).name.include? 'worker'
  unless (machines.max_by(&:created_at).name.include? 'worker')
     logger.warn "Skipping this scenario because the last provisioned machine is not worker."	  
     skip_this_scenario
 end
end
