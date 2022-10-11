Given(/^I pick a random( windows)? machineset to scale$/) do | windows |
  ensure_admin_tagged
  machine_sets = BushSlicer::MachineSetMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api")).
    select { |ms| ms.available_replicas >= 1 && (windows ? ms.is_windows_machinesets? : !ms.is_windows_machinesets?) }
  cache_resources *machine_sets.shuffle
end

Given(/^I pick a earliest created machineset and store in#{OPT_SYM} clipboard$/) do | cb_name | 
  ensure_admin_tagged
  machine_sets = BushSlicer::MachineSetMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machine_sets
  cb[cb_name] = machine_sets.min_by(&:created_at).name
end

When(/^I scale the machineset to ([\+\-]?)#{NUMBER}$/) do | op, num |
  ensure_destructive_tagged

  case op
  when "-"
    replicas = machine_set_machine_openshift_io.available_replicas - num.to_i
  when "+"
    replicas = machine_set_machine_openshift_io.available_replicas + num.to_i
  when ""
    replicas = num.to_i
  else
    raise "wrong operation #{op.inspect} supplied"
  end

  step %Q/I run the :scale admin command with:/, table(%{
    | n        | openshift-machine-api                        |
    | resource | machinesets.machine.openshift.io             |
    | name     | <%= machine_set_machine_openshift_io.name %> |
    | replicas | #{replicas.to_s}                             |
  })
end

Then(/^the machineset should have expected number of running machines$/) do
  machine_set_machine_openshift_io.wait_till_ready(admin, 900)

  num_running_machines = 0
  machine_set_machine_openshift_io.machines.each do | machine |
    if machine.deleting?
      step %Q{I wait for the resource "machines.machine.openshift.io" named "#{machine.name}" to disappear within 1200 seconds}
      step %Q{the step should succeed}
      next
    end

    # wait till machine's node is ready
    success = wait_for(900, interval: 20) {
      machine.get if machine.node_name.nil?
      node(machine.node_name).ready?[:success]
    }
    unless success
      raise "Node #{machine.node_name} has not become ready"
    end

    num_running_machines+=1
  end

  available_replicas = machine_set_machine_openshift_io.available_replicas(user: nil, cached: false, quiet: false)
  if available_replicas != num_running_machines
    raise "Machineset #{machine_set_machine_openshift_io.name} has #{num_running_machines} running machines, expected #{available_replicas}"
  end
end

Given(/^I clone a( windows)? machineset and name it "([^"]*)"$/) do | os_type, ms_name |
  step %Q{I pick a random#{os_type} machineset to scale}

  ms_yaml = machine_set_machine_openshift_io.raw_resource.to_yaml
  new_spec = YAML.load ms_yaml
  new_spec["metadata"]["name"] = ms_name
  new_spec["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] = ms_name
  new_spec["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] = ms_name
  # Adding taints to machineset so that pods without toleration can not schedule to the nodes we provision
  new_spec["spec"]["template"]["spec"]["taints"] = [{"effect": "NoSchedule","key": "mapi","value": "mapi_test"}]
  new_spec["spec"]["replicas"] = 1
  new_spec.delete("status")

  BushSlicer::MachineSetMachineOpenshiftIo.create(by: admin, project: project("openshift-machine-api"), spec: new_spec)
  step %Q{admin ensures "#{ms_name}" machine_set_machine_openshift_io is deleted after scenario}

  machine_sets = BushSlicer::MachineSetMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machine_sets.max_by(&:created_at)

  step %Q{the machineset should have expected number of running machines}
end

Given(/^I create a spot instance machineset and name it "([^"]*)" on (aws|gcp|azure)$/) do | ms_name, iaas_type |
  step %Q{I pick a random machineset to scale}

  ms_yaml = machine_set_machine_openshift_io.raw_resource.to_yaml
  new_spec = YAML.load ms_yaml
  new_spec["metadata"]["name"] = ms_name
  new_spec["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] = ms_name
  new_spec["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] = ms_name
  if iaas_type == 'aws'
    new_spec["spec"]["template"]["spec"]["providerSpec"]["value"]["spotMarketOptions"] = {}
  elsif iaas_type == 'gcp'
    new_spec["spec"]["template"]["spec"]["providerSpec"]["value"]["preemptible"] = true
  elsif iaas_type == 'azure'
    new_spec["spec"]["template"]["spec"]["providerSpec"]["value"]["spotVMOptions"] = {}
  else
    raise "spot instance not supported on #{iaas_type}"
  end
  new_spec["spec"]["replicas"] = 1
  new_spec.delete("status")

  BushSlicer::MachineSetMachineOpenshiftIo.create(by: admin, project: project("openshift-machine-api"), spec: new_spec)
  step %Q{admin ensures "#{ms_name}" machine_set_machine_openshift_io is deleted after scenario}

  machine_sets = BushSlicer::MachineSetMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api"))
  cache_resources *machine_sets.max_by(&:created_at)

  step %Q{the machineset should have expected number of running machines}
end
