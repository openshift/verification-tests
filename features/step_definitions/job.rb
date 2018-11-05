Given /^I wait until job "(.+)" completes$/ do |job_name|
  ready_timeout = 5 * 60
  @result = job(job_name).wait_till_ready(user, ready_timeout)

  raise "job #{job.name} never completed" unless @result[:success]
end
