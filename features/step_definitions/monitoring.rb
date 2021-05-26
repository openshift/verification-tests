Then(/^I check replicas of monitoring components for sno cluster$/) do

  if infrastructure("cluster").infra_topology=="SingleReplica"

    project("openshift-monitoring") 
    #check deamonset replicas
    step %Q/I run the :get client command with:/, table(%{
      | resource   | daemonset            |
      | n          | openshift-monitoring |
      | no_headers | true                 |
    })
    step %Q/the step should succeed/
    daemonsets=@result[:stdout].split(/\n/).map{|n| n.split(/\s/)[0]}    
    for index in 0 ... daemonsets.size
      desired_replica=daemon_set(daemonsets[index]).replica_counters(cached: false)[:desired]
      if desired_replica!=1
        raise "daemonsets #{daemonsets[index]} has wrong replica #{desired_replica}, expected 1"
      end
    end
    #check statefulset replicas
    step %Q/I run the :get client command with:/, table(%{
      | resource   | statefulset          |
      | n          | openshift-monitoring |
      | no_headers | true                 |
    })
    step %Q/the step should succeed/
    statefulsets=@result[:stdout].split(/\n/).map{|n| n.split(/\s/)[0]} 
    for index in 0 ... statefulsets.size
      desired_replica=stateful_set(statefulsets[index]).replica_counters(cached: false)[:desired]
      if desired_replica!=1
        raise "statefulsets #{statefulsets[index]} has wrong replica #{desired_replica}, expected 1"
      end
    end
    #check deployment replicas
    step %Q/I run the :get client command with:/, table(%{
      | resource   | deployment           |
      | n          | openshift-monitoring |
      | no_headers | true                 |
    })
    step %Q/the step should succeed/
    deployments=@result[:stdout].split(/\n/).map{|n| n.split(/\s/)[0]}
    for index in 0 ... deployments.size
      desired_replica=deployment(deployments[index]).replica_counters(cached: false)[:desired]
      if desired_replica!=1
        raise "deployment #{deployments[index]} has wrong replica #{desired_replica}, expected 1"
      end
    end    

    project("openshift-user-workload-monitoring") 
    #check statefulset replicas
    step %Q/I run the :get client command with:/, table(%{
      | resource   | statefulset                        |
      | n          | openshift-user-workload-monitoring |
      | no_headers | true                               |
    })
    step %Q/the step should succeed/
    user_statefulsets=@result[:stdout].split(/\n/).map{|n| n.split(/\s/)[0]} 
    for index in 0 ... user_statefulsets.size
      desired_replica=stateful_set(user_statefulsets[index]).replica_counters(cached: false)[:desired]
      if desired_replica!=1
        raise "statefulsets #{user_statefulsets[index]} has wrong replica #{desired_replica}, expected 1"
      end
    end
    #check deployment replicas
    step %Q/I run the :get client command with:/, table(%{
      | resource   | deployment                         |
      | n          | openshift-user-workload-monitoring |
      | no_headers | true                               |
    })
    step %Q/the step should succeed/
    user_deployments=@result[:stdout].split(/\n/).map{|n| n.split(/\s/)[0]}
    for index in 0 ... user_deployments.size
      desired_replica=deployment(user_deployments[index]).replica_counters(cached: false)[:desired]
      if desired_replica!=1
        raise "deployment #{user_deployments[index]} has wrong replica #{desired_replica}, expected 1"
      end
    end
  end
end