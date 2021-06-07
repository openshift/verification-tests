Then(/^I check replicas of monitoring components for sno cluster$/) do

  if infrastructure("cluster").infra_topology=="SingleReplica"

    step %Q/there is 1 "daemonset" replicas in the "openshift-monitoring" project/
    step %Q/there is 1 "statefulset" replicas in the "openshift-monitoring" project/
    step %Q/there is 1 "deployment" replicas in the "openshift-monitoring" project/
    step %Q/there is 1 "daemonset" replicas in the "openshift-monitoring" project/
    step %Q/there is 1 "statefulset" replicas in the "openshift-user-workload-monitoring " project/
    step %Q/there is 1 "deployment" replicas in the "openshift-user-workload-monitoring" project/

  end
end