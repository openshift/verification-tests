# container related steps
#
Given /^I wait for the container(?: named #{QUOTED})? of the #{QUOTED} pod to terminate with reason #{SYM}$/ do |container_name, pod_name, reason|
  ready_timeout = 15 * 60
  @result = pod(pod_name).container(user: user, name: container_name).wait_till_completed(ready_timeout)

  unless @result[:success]
    raise "#{name} container did not become completed"
  end
end

Given /^I wait for the container(?: named #{QUOTED})? of the #{QUOTED} pod to reach waiting "(.*?)" state(?: within #{NUMBER} seconds)?$/ do |container_name, pod_name, state_reason, timeout|
	timeout = timeout ? Integer(timeout) : 3 * 60
  matched_c_status = []
	success = wait_for(timeout){
		matched_c_status = pod(pod_name).status_raw["containerStatuses"].select { |c| c['name'] == container_name}
		logger.info("Got #{matched_c_status}")
		matched_c_status[0]['ready'] == false && matched_c_status[0]['state'].keys().join() == 'waiting' && matched_c_status[0]['state']['waiting']['reason'] == state_reason
	}
  if success
    cb[:container_state_msg] = matched_c_status[0]['state']['waiting']['message'].slice(10, 15)
  else
    raise "#{container_name} container did not reach pending state #{state_reason} within timeouts #{timeout}"
  end
end