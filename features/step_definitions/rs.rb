# frozen_string_literal: true

require 'active_support/core_ext/hash/slice.rb'

### replicaSet related steps

Given /^I wait until number of replicas match "(\d+)" for replicaSet "(.+)"$/ do |number, rs_name|
  transform binding, :number, :rs_name
  ready_timeout = 300
  matched = rs(rs_name).wait_till_replica_counters_match(
    user: user,
    seconds: ready_timeout,
    replica_count: number.to_i
  )
  unless matched[:success]
    raise "desired replica count not reached within timeout"
  end
end

Given /^number of replicas of#{OPT_QUOTED} replica set becomes:$/ do |name, table|
  transform binding, :name, :table
  options = hash_symkeys(table.rows_hash)

  int_keys = %i[seconds] + BushSlicer::ReplicaSet::REPLICA_COUNTERS.keys
  int_options = options.slice(*int_keys)
  int_options.transform_values!(&:to_i)
  int_options[:seconds] ||= 5 * 60

  misc_keys = %i[user]
  options = options.slice(*misc_keys).merge(int_options)
  options[:user] ||= user

  matched = rs(name).wait_till_replica_counters_match(**options)

  raise 'expected replica set replica counters not reached within timeout' unless matched[:success]
end
