Given(/^I store all machineconfigs in the#{OPT_SYM} clipboard$/) do | cb_name |
  machineconfigs = BushSlicer::MachineConfig.list(user: admin)
  cache_resources *machineconfigs
  cb[cb_name] = machineconfigs
end

