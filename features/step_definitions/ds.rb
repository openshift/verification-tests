# frozen_string_literal: true

require 'active_support/core_ext/hash/slice.rb'
require 'active_support/core_ext/hash/transform_values.rb'

Given /^number of replicas of#{OPT_QUOTED} daemon set becomes:$/ do |name, table|
  options = hash_symkeys(table.rows_hash)

  int_keys = %i[seconds] + BushSlicer::DaemonSet::REPLICA_COUNTERS.keys
  int_options = options.slice(*int_keys)
  int_options.transform_values!(&:to_i)
  int_options[:seconds] ||= 5 * 60

  misc_keys = %i[user]
  options = options.slice(*misc_keys).merge(int_options)
  options[:user] ||= user

  matched = daemon_set(name).wait_till_replica_counters_match(**options)

  raise 'expected replica set replica counters not reached within timeout' unless matched[:success]
end

Given /^current generation number of#{OPT_QUOTED} daemonset is stored into#{OPT_SYM} clipboard$/ do |name, cb_name|
  cb_name ||= :generation_number
  cb[cb_name] = daemon_set(name).generation_number(user: user, cached: false)
end

Given /desired number of#{OPT_QUOTED} daemonset is stored into#{OPT_SYM} clipboard$/ do |name, cb_name|
  cb_name ||= :desired_num
  cb[cb_name] = daemon_set(name).desired_replicas
end
