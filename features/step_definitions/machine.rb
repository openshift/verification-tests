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
  cb.all_machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  machine_orig_num = cb.all_machines.length

  teardown_add {
    machines_waiting_delete = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api")).select { | machine |
      machine.deleting?
    }

    machines_waiting_delete.each do | machine |
      step %Q{I use the "openshift-machine-api" project}
      step %Q{I wait for the resource "machine" named "#{machine.name}" to disappear within 1200 seconds}
      step %Q{the step should succeed}
    end

    machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
    unless machines.length == machine_orig_num
      raise "Failed to restore cluster, expected number of machines #{machine_orig_num}, got #{machines.length.to_s}"
    end
  }
end
