### replicationController related steps

# to reliably wait for all the replicas to be come ready, we do
# 'oc get rc <rc_name>' and wait until the spec['replicas'] == status['replicas']
Given /^(I|admin) waits? until replicationController#{OPT_QUOTED} is ready$/ do |who, rc_name|
  transform binding, :who, :rc_name
  ready_timeout = 15 * 60
  who = who == "admin" ? admin : user
  @result = rc(rc_name).wait_till_ready(who, ready_timeout)

  raise "replication controller #{rc.name} never became ready" unless @result[:success]
end

# Given /^I wait until the status of replication controller "(.+)" becomes :(.+)$/ do |resource_name, status|
#   ready_timeout = 10 * 60
#   rc(resource_name).wait_till_status(status.to_sym, user, ready_timeout)
# end

Given /^I wait until number of(?: "(.*?)")? replicas match "(\d+)" for replicationController "(.+)"$/ do |state, number, rc_name|
  transform binding, :state, :number, :rc_name
  ready_timeout = 300
  state = :running if state.nil?
  @result = rc(rc_name).wait_till_replica_counters_match(
    user: user,
    state.to_sym => number.to_i,
    seconds: ready_timeout,
  )

  unless @result[:success]
    raise "desired replica count not reached within timeout"
  end
end

Given /^a replicationController becomes ready with labels:$/ do |table|
  transform binding, :table
  labels = table.raw.flatten # dimentions irrelevant
  rc_timeout = 10 * 60
  ready_timeout = 15 * 60

  @result = BushSlicer::ReplicationController.wait_for_labeled(*labels, user: user, project: project, seconds: rc_timeout)

  if @result[:matching].empty?
    raise "See log, waiting for labeled rcs futile: #{labels.join(',')}"
  end

  cache_resources(*@result[:matching])
  @result = rc.wait_till_ready(user, ready_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{rc.name} replication_controller did not become ready"
  end
end
