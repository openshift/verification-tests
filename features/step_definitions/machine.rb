Given(/^I have an IPI deployment$/) do
  # In an IPI deployment, machine number equals to node number
  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  if machines.length == 0
    raise "Not an IPI deployment, there are no machines"
  end

  machines.each do | machine |
    if machine.node_name.nil?
      raise "machine #{machine.name} has no node ref, this is not a ready IPI deployment."
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

Then(/^admin ensures machine number is restored after scenario$/) do
  ensure_admin_tagged
  machine_names_orig = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api")).map { | m | m.name }

  teardown_add {
    machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))

    # compare current macine names and original machine names, new names are waiting delete
    machine_names_current = machines.map { | m | m.name }
    machine_names_waiting_del = machine_names_current - machine_names_orig
    return if machine_names_waiting_del.empty?

    machines_waiting_delete = []
    machines.each do | machine |
      machines_waiting_delete << machine if machine_names_waiting_del.include?(machine.name)
    end

    machines_waiting_delete.each do | machine |
      machine.ensure_deleted(user: user, wait: 1200)
      raise "Unable to delete machine #{machine.name}" if machine.exists?(user: user)
    end
  }
end
