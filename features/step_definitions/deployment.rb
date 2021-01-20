# frozen_string_literal: true

require 'active_support/core_ext/hash/slice.rb'

### Deployment related steps

Given /^I wait until number of replicas match "(\d+)" for deployment "(.+)"$/ do |number, d_name|
  ready_timeout = 300
  matched = deployment(d_name).wait_till_replica_counters_match(
    user:          user,
    seconds:       ready_timeout,
    replica_count: number.to_i,
  )
  unless matched[:success]
    raise "desired replica count not reached within timeout"
  end
end

Given /^number of replicas of#{OPT_QUOTED} deployment becomes:$/ do |name, table|
  options = hash_symkeys(table.rows_hash)

  int_keys = %i[seconds] + BushSlicer::Deployment::REPLICA_COUNTERS.keys
  int_options = options.slice(*int_keys)
  int_options.transform_values!(&:to_i)
  int_options[:seconds] ||= 5 * 60

  misc_keys = %i[user]
  options = options.slice(*misc_keys).merge(int_options)
  options[:user] ||= user

  matched = deployment(name).wait_till_replica_counters_match(**options)

  raise 'expected deployment replica counters not reached within timeout' unless matched[:success]
end

Given /^number of replicas of the current replica set for the#{OPT_QUOTED} deployment becomes:$/ do |name, table|
  options = hash_symkeys(table.rows_hash)

  int_keys = %i[seconds] + BushSlicer::ReplicaSet::REPLICA_COUNTERS.keys
  int_options = options.slice(*int_keys)
  int_options.transform_values!(&:to_i)
  int_options[:seconds] ||= 5 * 60

  misc_keys = %i[user]
  options = options.slice(*misc_keys).merge(int_options)
  options[:user] ||= user

  matched = deployment(name)
    .current_replica_set(user: options[:user])
    .wait_till_replica_counters_match(**options)

  raise 'expected replica set replica counters not reached within timeout' unless matched[:success]
end

Given /^current replica set name of#{OPT_QUOTED} deployment stored into#{OPT_SYM} clipboard$/ do |name, cb_name|
  cb[cb_name] = deployment(name).current_replica_set(user: user, cached: false).name
end

Given /^replica set #{QUOTED} becomes non-current for the #{QUOTED} deployment$/ do |rs_name, name|
  seconds = 180
  deplmnt = deployment(name)
  success = wait_for(seconds) do
    rs_name != deplmnt.current_replica_set(user: user, cached: false).name
  end
  raise 'expected replica set name change not reached within timeout' unless success
end

Given /^#{QUOTED} deployment becomes ready in the#{OPT_QUOTED} project$/ do | d_name, proj_name |
  proj_name ||= project.name
  project(proj_name)
  seconds = 5 * 60
  success = wait_for(seconds) {
    desired = deployment(d_name).desired_replicas
    ready = deployment(d_name).ready_replicas(cached: false)
    ready == desired
  }
  raise "Deployment did not become ready" unless success
end

Given /^admin ensures the deployment replicas is restored to "([^"]*)" in "([^"]*)" for "([^"]*)" after scenario$/ do | replicas , project , deployment |
  ensure_admin_tagged
  teardown_add{
  step %Q{I run the :scale admin command with:}, table(%{
     | resource | deployment    |
     | name     | #{deployment} |
     | replicas | #{replicas}   |
     |  n       | #{project}    |
  })
  step %Q/the step should succeed/
}
end

