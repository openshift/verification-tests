Given(/^I use the "([^"]*)" service$/) do |service_name|
  service(service_name)
end

Given /^I reload the(?: "([^"]*)")? service$/ do |service_name|
  transform binding, :service_name
  @result = service(service_name).get_checked(user: user)
end

Given(/^I wait for the(?: "([^"]*)")? service to be created$/) do |name|
  @result = service(name).wait_to_appear(user, 60)

  unless @result[:success]
    raise "timeout waiting for service #{name} to be created"
  end
end

Given /^I get the#{OPT_QUOTED} service pods$/ do |svc_name|
  transform binding, :svc_name
  cache_resources *service(svc_name).pods(cached: false)
end
