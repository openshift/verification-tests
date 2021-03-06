# frozen_string_literal: true

require 'active_support/core_ext/hash/slice.rb'

Given /^I wait until the status of deployment "(.+)" becomes :(.+)$/ do |resource_name, status|
  transform binding, :resource_name, :status
  ready_timeout = 10 * 60
  @result = dc(resource_name).wait_till_status(status.to_sym, user, ready_timeout)
  unless @result[:success]
    user.cli_exec(:logs, resource_name: "dc/#{resource_name}")
    raise "dc #{resource_name} never became #{status}"
  end
end

Given /^(I|admin) stores? in the#{OPT_SYM} clipboard the replication controller of deployment config #{QUOTED}(?: from the #{QUOTED} project)?$/ do |who, cb_name, dc_name, project_name|
  transform binding, :who, :cb_name, :dc_name, :project_name
  cb_name ||= 'rc'
  who = who == "admin" ? admin : user
  _rc = dc(dc_name, project(project_name, switch: false)).rc(user: who, cached: false)
  cache_resource _rc
  cb[cb_name] = _rc
end

# Given /^(I|admin) waits? version #{NUMBER} of deployment config#{OPT_QUOTED}(?: from the #{QUOTED} project)? to become ready$/ do |who, version, dc_name, project_name|
#   ready_timeout = 5 * 60
#   who = who == "admin" ? admin : user
#   _rc = rc("#{dc_name}-#{version}", project(project_name))
#   @result = _rc.wait_till_ready(who, ready_timeout)
#   unless @result[:success]
#     raise "rc '#{_rc.name}' did not become ready within the timeout"
#   end
# end

# restore the selected dc in teardown by getting current deployment and do:
#   'oc rollback <dc_name> --to-version=<saved_good_version>'
Given /^default (router|docker-registry) deployment config is restored after scenario$/ do |resource|
  transform binding, :resource
  ensure_destructive_tagged
  _admin = admin
  _project = project("default", switch: false)
  # first we need to save the current version

  # TODO: maybe we just use dc status => latestVersion ?
  _rc = BushSlicer::ReplicationController.get_labeled(
    resource,
    user: _admin,
    project: _project
  ).max_by {|rc| rc.created_at}

  raise "no matching rcs found" unless _rc
  version = _rc.annotation("openshift.io/deployment-config.latest-version")
  unless _rc.ready?(user: admin, cached: true)
    raise "latest rc version #{version} is bad"
  end

  cb["#{resource.tr("-","_")}_golden_version"] = Integer(version)
  logger.info "#{resource} will be rolled-back to version #{version}"
  teardown_add {
    @result = _admin.cli_exec(:rollback, deployment_name: resource, to_version: version, n: _project.name)
    raise "Cannot restore #{resource}" unless @result[:success]
    latest_version = @result[:response].match(/#(\d+)/)[1]
    rc_name = resource + "-" + latest_version
    @result = rc(rc_name, _project).wait_till_ready(_admin, 900)
    raise "#{rc_name} didn't become ready" unless @result[:success]
  }
end

Given /^default (docker-registry|router) replica count is restored after scenario$/ do |resource|
  transform binding, :resource
  ensure_destructive_tagged
  _admin = admin
  _project = project("default", switch: false)
  _dc = dc(resource, _project)
  _num = _dc.replicas(user: _admin)
  logger.info("#{resource} replicas will be restored to #{_num} after scenario")

  teardown_add {
    if _num != _dc.replicas(user: _admin, cached: false, quiet: true)
      @result = _admin.cli_exec(:scale,
                                resource: "deploymentconfigs",
                                name: _dc.name,
                                replicas: _num,
                                n: _project.name)
      raise "could not restore #{_dc.name} replica num" unless @result[:success]

      # paranoya check no bad caching takes place
      num_replicas_restored = wait_for(60) {
        _num == _dc.replicas(user: _admin, cached: false, quiet: true)
      }
      unless num_replicas_restored
        raise "#{_dc.name} replica num still not restored?!"
      end

      @result = _dc.wait_till_ready(_admin, 900)
      raise "scale unsuccessful for #{_dc.name}" unless @result[:success]
    else
      logger.warn("#{resource} replica num is the same after scenario")
    end
  }
end

Given /^number of replicas of#{OPT_QUOTED} deployment config becomes:$/ do |name, table|
  transform binding, :name, :table
  options = hash_symkeys(table.rows_hash)

  int_keys = %i[seconds] + BushSlicer::DeploymentConfig::REPLICA_COUNTERS.keys
  int_options = options.slice(*int_keys)
  int_options.transform_values!(&:to_i)
  int_options[:seconds] ||= 5 * 60

  misc_keys = %i[user]
  options = options.slice(*misc_keys).merge(int_options)
  options[:user] ||= user

  matched = dc(name).wait_till_replica_counters_match(**options)

  raise 'expected deployment config replica counters not reached within timeout' unless matched[:success]
end

Given /^(I|admin) redeploys? #{QUOTED} dc( after scenario)?$/ do |who, dc_name, at_teardown|
  transform binding, :who, :dc_name, :at_teardown
  _user = who == "admin" ? admin : user
  _dc = dc(dc_name)

  p = proc {
    original_version = _dc.latest_version(user: _user)

    # throw out a rollout cancel in case it is presently stuck in deployment
    @result = _user.cli_exec(:rollout_cancel, resource: "dc",
                             name: _dc.name,
                             n: _dc.project.name)
    sleep 10 if @result[:success] # if it was cancelled, wait a little bit

    _dc.rollout_latest(user: _user)
    updated = wait_for(180) {
      _dc.latest_version(user: _user) != original_version
    }

    unless updated
      raise "dc didn't update version, still on: #{original_version}"
    end

    @result = _dc.rc(user: _user).wait_till_ready(_user, 180)

    unless @result[:success]
      raise "dc didn't become ready in time, see log"
    end
  }

  if at_teardown
    teardown_add p
  else
    p.call
  end
end

Given /^master CA is added to the#{OPT_QUOTED} dc$/ do |name|
  transform binding, :name

  step %Q/certification for default image registry is stored to the :reg_crt_name clipboard/
  step %Q/I run the :create_configmap client command with:/, table(%{
    | name      | ca                     |
    | from_file | <%= cb.reg_crt_name %> |
  })
  step %Q/the step should succeed/

  step %Q/I check that the "#{name}" dc exists/

  steps """
    When I run the :rollout_pause client command with:
      | resource | dc      |
      | name     | #{name} |
    Then the step should succeed
    When I run the :set_volume client command with:
      | resource       | dc/#{name}      |
      | add            | true            |
      | type           | configmap       |
      | configmap-name | ca              |
      | mount-path     | /opt/qe/ca      |
    Then the step should succeed
    When I run the :label client command with:
      | resource | dc          |
      | name     | #{name}     |
      | key_val  | mastercert=#{name} |
    Then the step should succeed
    When I run the :rollout_resume client command with:
      | resource | dc      |
      | name     | #{name} |
    Then the step should succeed
  """

  step %Q/a replicationController becomes ready with labels:/, table(%{
        | mastercert=#{name} |
    })

  dc.rc = rc
  cache_resources *rc.pods(user:user, quiet: true)
end

Given /^a deploymentConfig becomes ready with labels:$/ do |table|
  transform binding, :table
  labels = table.raw.flatten # dimentions irrelevant
  dc_timeout = 10 * 60
  ready_timeout = 15 * 60

  @result = BushSlicer::DeploymentConfig.wait_for_labeled(*labels, user: user, project: project, seconds: dc_timeout)

  if @result[:matching].empty?
    raise "See log, waiting for labeled dcs futile: #{labels.join(',')}"
  end

  cache_resources(*@result[:matching])
  @result = dc.wait_till_ready(user, ready_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{dc.name} deployment_config did not become ready"
  end
end

Given /^build configs that trigger the#{OPT_QUOTED} dc are stored in the#{OPT_SYM} clipboard$/ do |dc_name, cb_name|
  transform binding, :dc_name, :cb_name
  cb_name ||= :dcbcs

  cb[cb_name] = dc(dc_name).trigger_build_configs(cached: false)
  cache_resources *cb[cb_name]
end
