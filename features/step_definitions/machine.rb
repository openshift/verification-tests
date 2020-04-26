Given(/^I have an IPI deployment$/) do
  machine_sets = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machine_sets

  # Usually UPI deployments do not have machineSets
  if machine_sets.length == 0
    raise "Not an IPI deployment, abort test."
  end

  machine_sets.each do | machine_set |
    unless machine_set.ready?[:success]
      raise "Not an IPI deployment or machineSet #{machine_set.name} not fully scaled, abort test."
    end
  end
end

Then(/^the machines should be linked to nodes$/) do
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  machines.each do | machine |
    if machine.node_name == nil
      raise "Machine #{machine.name} does not have nodeRef."
    end
  end
end

Given(/^I store the number of machines in the#{OPT_SYM} clipboard$/) do | cb_name |
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  cb[cb_name] = machines.length
end


Given(/^I store the last provisioned machine in the#{OPT_SYM} clipboard$/) do | cb_name |
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  cb[cb_name] = machines.max_by(&:created_at).name
end

Given(/^I wait for the node of machine(?: named "(.+)")? to appear/) do | machine_name |
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines

  machine = machines.select { |m | m.name == machine_name }.first
  cache_resources *machine

  wait_for(600, interval: 10) {
    machine.get
    ! machine.node_name.nil?
  }

  node_name = machine.node_name
  if node_name.nil?
    raise "Machine #{machine_name} does not have nodeRef"
  end

  cb["new_node"] = node_name
end

Then(/^admin ensures node number is restored to #{QUOTED} after scenario$/) do | num_expected |
  ensure_admin_tagged

  teardown_add {
    num_actual = 0

    success = wait_for(900, interval: 20) {
      num_actual = BushSlicer::Node.list(user: admin).length
      num_expected == num_actual.to_s
    }
    raise "Failed to restore cluster, expected number of nodes #{num_expected}, got #{num_actual.to_s}" unless success
  }
end
