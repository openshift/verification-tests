Given(/^I have an IPI deployment$/) do
  machine_sets = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api"))

  # Usually UPI deployments do not have machineSets
  if machine_sets.length == 0 
    raise "Not an IPI deployment, abort test."
  end

  machine_sets.each do | machine_set |
    unless machine_set.healthy?
      raise "Not an IPI deployment, abort test."
    end
  end
end

Then(/^the machines should be linked to nodes$/) do
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  machines.each do | machine |
    if machine.linked_node == nil
      raise "Machine #{machine.name} does not have nodeRef."
    end
  end
end
