# machineset supporting steps
#
Given /^I store all machinesets to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :machinesets
  @result = admin.cli_exec(:get, resource: 'machineset', n: 'openshift-machine-api', o: 'yaml')
  cb[cb_name] = @result[:parsed]["items"].map { |i| i['metadata']['name']}
end


