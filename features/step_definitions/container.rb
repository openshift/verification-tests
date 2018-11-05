# container related steps
#
Given /^I wait for the container(?: named #{QUOTED})? of the #{QUOTED} pod to terminate with reason #{SYM}$/ do |container_name, pod_name, reason|
  ready_timeout = 15 * 60
  @result = pod(pod_name).container(user: user, name: container_name).wait_till_completed(ready_timeout)

  unless @result[:success]
    raise "#{name} container did not become completed"
  end
end

