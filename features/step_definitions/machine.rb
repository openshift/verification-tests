Given(/^I have an IPI deployment$/) do
  # In an IPI deployment, machine number equals to node number
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  if machines.length == 0
    logger.warn "Not an IPI deployment, there are no machines"
    logger.warn "We will skip this scenario"
    skip_this_scenario
  end

  machines.each do | machine |
    if machine.node_name.nil?
      logger.warn "machine #{machine.name} has no node ref, this is not a ready IPI deployment."
      logger.warn "We will skip this scenario"
      skip_this_scenario
    end
  end
end

Given(/^I have an UPI deployment and machinesets are enabled$/) do
  # In an UPI deployment, if enabled machinesets, machines should be linked to nodes
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  if machines.length == 0
    logger.warn "Machinesets are not enabled, there are no machines"
    logger.warn "We will skip this scenario"
    skip_this_scenario
  end

  machines.each do | machine |
    if machine.node_name.nil?
      logger.warn "machine #{machine.name} has no node ref."
      logger.warn "We will skip this scenario"
      skip_this_scenario
    end
  end
end

Then(/^the machines should be linked to nodes$/) do
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  machines.each do | machine |
    if machine.node_name == nil
      raise "Machine #{machine.name} does not have nodeRef."
    end
  end
end

Given(/^I store the number of machines in the#{OPT_SYM} clipboard$/) do | cb_name |
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  cb[cb_name] = machines.length
end


Given(/^I store the last provisioned machine in the#{OPT_SYM} clipboard$/) do | cb_name |
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machines
  cb[cb_name] = machines.max_by(&:created_at).name
end

Given(/^I wait for the node of machine_machine_openshift_io(?: named "(.+)")? to appear/) do | machine_name |
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
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

Then(/^admin ensures machine number is restored after scenario$/) do
  ensure_admin_tagged
  machine_names_orig = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api")).map(&:name)

  teardown_add {
    machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
    machine_names_current = machines.map(&:name)
    machine_names_waiting_del = machine_names_current - machine_names_orig
    machine_names_missing = machine_names_orig - machine_names_current
    machines_waiting_delete = machines.select { |m| machine_names_waiting_del.include?(m.name) }

    unless machine_names_missing.empty?
      raise "Machines deleted but never restored: #{machine_names_missing}."
    end

    # Instead of delete a machine, wait for the deletion to complete, then loop another one.
    # We trigger a delete cmd for all machines, then wait for the deletions to complete
    machines_waiting_delete.each do | machine |
      # deleted object but does not wait for completion
      machine.delete_graceful(by: user)
    end
    machines_waiting_delete.each do | machine |
      # wait for the deletion to complete
      machine.ensure_deleted(user: user, wait: 1200)
      raise "Unable to delete machine #{machine.name}" if machine.exists?(user: user)
    end
  }
end
