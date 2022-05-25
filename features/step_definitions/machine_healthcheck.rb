When(/^I create the 'Ready' unhealthyCondition$/) do
  ensure_destructive_tagged

  # pick a random node from the machines
  machines = BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project("openshift-machine-api")).
    select { |m| m.machine_set_name == machine_set_machine_openshift_io.name }
  cache_resources *machines.shuffle

  # somtimes PDB may prevent a successful node-drain thus blocks the test
  # annnotate the machine to exclude node-drain so that test does not flake
  killer_pod_tmpl = "#{BushSlicer::HOME}/testdata/cloud/mhc/kubelet-killer-pod.yml"

  # this is no longer needed after 4.4
  if env.version_le("4.3", user: user)
    step %Q{I run the :annotate client command with:}, table(%{
      | n            | openshift-machine-api                       |
      | resource     | machine                                     |
      | resourcename | #{machine_machine_openshift_io.name}        |
      | overwrite    | true                                        |
      | keyval       | machine.openshift.io/exclude-node-draining= |
    })
    killer_pod_tmpl = "#{BushSlicer::HOME}/testdata/cloud/mhc/kubelet-killer-pod-43.yml"
  end

  # create a priviledged pod that kills kubelet on its node
  step %Q{I run oc create over "#{killer_pod_tmpl}" replacing paths:}, table(%{
    | n                    | openshift-machine-api                     |
    | ["spec"]["nodeName"] | #{machine_machine_openshift_io.node_name} |
  })
  step %Q{the step should succeed}
end

 Then(/^the machine(?: named "(.+)")? should be remediated$/) do | machine_name |
   machine_name = machine_machine_openshift_io.name if machine_name.nil?
   # unhealthy machine and should be deleted
   step %Q{I wait for the resource "machines.machine.openshift.io" named "#{machine_name}" to disappear within 1200 seconds}
   # new machine and node should provisioned
   step %Q{the machineset should have expected number of running machines}
 end
