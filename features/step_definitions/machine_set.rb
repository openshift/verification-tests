# machineset supporting steps
#

Given(/^I pick a random machineset to scale$/) do
  ensure_admin_tagged
  machine_sets = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api"))
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

  machines = BushSlicer::Machine.list(user: admin, project: project("openshift-machine-api"))

  num_running_machines = 0
  machines.each do | machine |
    next if machine.machine_set_name != machine_set.name

    # if machine phase is 'Deleting' then wait for its node to disappear
    if machine.phase == 'Deleting'
      step %Q{I wait for the resource "node" named "#{machine.node_name}" to disappear within 600 seconds}
      step %Q{I wait for the resource "machine" named "#{machine.name}" to disappear within 600 seconds}
      next
    end
    
    # wait till machine's node is ready
    machine.get
    unless node(machine.node_name).ready?[:success]
      raise "Node #{machine.node_name} has not become ready"
    end

    num_running_machines+=1
  end

  available_replicas = machine_set.available_replicas(user: nil, cached: false, quiet: false)
  if available_replicas != num_running_machines
    raise "Machineset #{machine_set.name} has #{num_running_machines} running machines, expected #{available_replicas}"
  end
end
