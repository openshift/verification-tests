### StatefulSet related steps

Given /^I wait until number of replica_count match "(\d+)" for StatefulSet "(.+)"$/ do |number, statefulset_name|
  transform binding, :number, :statefulset_name
  ready_timeout = 300
  @result = stateful_set(statefulset_name).wait_till_replica_counters_match(
    user: user,
    seconds: ready_timeout,
    replica_count: number.to_i
  )
  unless @result[:success]
    raise "desired replica count not reached within timeout"
  end
end
