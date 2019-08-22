# machineset supporting steps
#
Given /^I store all machinesets to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :machinesets
  cb[cb_name] = BushSlicer::MachineSet.list(user: admin, project: project("openshift-machine-api"))
end


