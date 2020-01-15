# machineset supporting steps
#
Given /^I store all machinesets to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :machinesets
  cb[cb_name] = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api"))
end

Given(/^I pick a random machineset to scale$/) do
  ensure_admin_tagged
  machine_sets = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api")).
    select { |m| m.available_replicas > 0 }
  cache_resources *machine_sets.shuffle
end

When(/^I scale the machineset to ([\+\-]?)#{NUMBER}$/) do | op, num |
  ensure_destructive_tagged

  case op
  when "-"
    replicas = machine_set.available_replicas - num.to_i
  when "+"
    replicas = machine_set.available_replicas + num.to_i
  when ""
    replicas = num.to_i
  else
    raise "wrong operation #{op.inspect} supplied"
  end

  step %Q/I run the :scale admin command with:/, table(%{
    | n        | openshift-machine-api   |
    | resource | machineset              |
    | name     | <%= machine_set.name %> |
    | replicas | #{replicas.to_s}        |
  })
end

Then(/^the machineset should have expected number of running machines$/) do
  machine_set.wait_till_ready(admin, 600)

  machines_all = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))
  machines = machines_all.select { |m| m.machine_set_name == machine_set.name }

  # Each node should be running
  machines.each do | machine |
    machine.get
    unless node(machine.node_name).ready?[:success]
      raise "Node #{machine.node_name} has not become ready."
    end
  end
end
