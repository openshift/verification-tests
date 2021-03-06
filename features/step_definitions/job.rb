Given /^I wait until job "(.+)" completes$/ do |job_name|
  transform binding, :job_name
  ready_timeout = 5 * 60
  @result = job(job_name).wait_till_ready(user, ready_timeout)

  raise "job #{job.name} never completed" unless @result[:success]
end

Given /^a job appears with labels:$/ do |table|
  transform binding, :table
  labels = table.raw.flatten
  job_timeout = 5 * 60

  jobs = project.jobs(by:user)

  @result = BushSlicer::Job.wait_for_labeled(*labels, user: user, project: project, seconds: job_timeout)
  if @result[:matching].empty?
    raise "See log, waiting for labeled jobs futile: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])
end
