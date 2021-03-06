When /^I give project (.+?) role to the(?: (.+?))? (user|service account)$/ do |role_name, user_name, user_type|
  transform binding, :role_name, :user_name, :user_type
  case user_type
  when "user"
    user_name=user(word_to_num(user_name), switch: false).name
  when "service account"
    user_name=service_account(user_name).full_id
  else
    raise "unknown user type: #{user_type}"
  end

  user.cli_exec(
    :policy_add_role_to_user,
    role: role_name,
    user_name: user_name,
    n: project.name,
    rolebinding_name: role_name
  )
end

When /^I remove project (.+?) role from the(?: (.+))? (user|service account)$/ do |role_name, user_name, user_type|
  transform binding, :role_name, :user_name, :user_type
  case user_type
  when "user"
    user_name=user(word_to_num(user_name), switch: false).name
  when "service account"
    user_name=service_account(user_name).full_id
  else
    raise "unknown user type: #{user_type}"
  end

  user.cli_exec(
    :policy_remove_role_from_user,
    role: role_name,
    user_name: user_name,
    n: project.name
  )
end

Given /^(the [a-z]+) user is cluster-admin$/ do |which_user|
  transform binding, :which_user
  ensure_admin_tagged
  step %Q{cluster role "cluster-admin" is added to the "#{which_user}" user}
end

Given /^cluster role #{QUOTED} is (added to|removed from) the #{QUOTED} (user|group|service account)$/ do |role, op, which, type|
  transform binding, :role, :op, :which, :type
  ensure_admin_tagged
  _admin = admin
  cluster_role(role)

  case type
  when "group"
    _add_command = :oadm_policy_add_cluster_role_to_group
    _remove_command = :oadm_policy_remove_cluster_role_from_group
    _subject = group(which)
    _subject_name = _subject.name
    _opts = {role_name: role, group_name: _subject.name}
  when "user", "service account"
    if type == "user"
      _subject = user(word_to_num(which), switch: false)
      _subject_name = _subject.name
    else
      _subject = service_account(which)
      _subject_name = _subject.full_id
    end

    _add_command = :oadm_policy_add_cluster_role_to_user
    _remove_command = :oadm_policy_remove_cluster_role_from_user
    _opts = {role_name: role, user_name: _subject_name}
  else
    raise "what is this subject type #{type}?!"
  end

  current_rbs = BushSlicer::ClusterRoleBinding.list(user: _admin, get_opts: {_quiet: true})
  case op
  when "added to"
    if current_rbs.any? { |crb| crb.role.name == role && crb.subjects.include?(_subject) }
      logger.info "#{_subject_name} already has role #{role}"
      next
    end
    _command = _add_command
    _teardown_command = _remove_command
  when "removed from"
    if current_rbs.none? { |crb| crb.role.name == role && crb.subjects.include?(_subject) }
      logger.info "#{_subject_name} does not have role #{role}"
      next
    end
    _command = _remove_command
    _teardown_command = _add_command
  else
    raise "unknown policy operation #{op}"
  end

  # we reattempt multiple times to workaround races where cluster policy is
  #   concurrently changed by another test executor
  wait_for(60, interval: 5) {
    @result = _admin.cli_exec(_command, **_opts)
    @result[:success]
  }
  if @result[:success]
    teardown_add {
      _res = nil
      wait_for(60, interval: 5) {
        _res = _admin.cli_exec(_teardown_command, **_opts)
        _res[:success]
      }
      raise "could not restore role of #{which} #{type}" unless _res[:success]
    }
  else
    raise "could not give #{which} #{type} the #{role} role"
  end
end

Given /^cluster roles are restored after scenario$/ do
  ensure_admin_tagged
  _admin = admin

  @result = _admin.cli_exec(:get, resource: 'clusterrole', o: 'yaml')
  if @result[:success]
    orig_policy = @result[:response]
    logger.info "clusterrole restore tear_down could be registered:\n"
  else
    raise "could not get clusterrole\n"
  end

  teardown_add {
    _admin.cli_exec(:oadm_policy_reconcile_cluster_roles, {confirm: 'true'})
  }
end

Given /^project role #{QUOTED} is (added to|removed from) the #{QUOTED} (user|group|service account)$/ do |role, op, which, type|
  transform binding, :role, :op, :which, :type
  case type
    when "group"
      _add_command = :oadm_policy_add_role_to_group
      _remove_command = :oadm_policy_remove_role_from_group
      _opts = {role_name: role, group_name: which}
    when "user", "service account"
      if type == "user"
        _user_name = user(word_to_num(which), switch: false).name
      else
        _user_name = service_account(which).full_id
      end
      _add_command = :oadm_policy_add_role_to_user
      _remove_command = :oadm_policy_remove_role_from_user
      _opts = {role_name: role, user_name: _user_name}
  end

  case op
    when "added to"
      _command = _add_command
    when "removed from"
      _command = _remove_command
    else
      raise "unknown policy operation #{op}"
  end

  @result = user.cli_exec(_command, **_opts)

end

Given /^the #{QUOTED} clusterole is recreated( after scenario)?$/ do |name, after_scenario|
  transform binding, :name, :after_scenario
  _admin = admin
  _csb = cluster_role(name)
  cb.cluster_resource_to_recreate = _csb
   verify = proc {
    success = wait_for(60, interval: 9) {
      _csb.exists?
    }
    unless success
      raise "could not find the clusterrole, see log"
    end
  }
   if after_scenario
    teardown_add verify
    step 'hidden recreate cluster resource after scenario'
  else
    step 'hidden recreate cluster resource'
    verify.call
  end
end

Given /^the #{QUOTED} clusterolebinding is recreated( after scenario)?$/ do |name, after_scenario|
  transform binding, :name, :after_scenario
  _admin = admin
  _csb = cluster_role_binding(name)
  cb.cluster_resource_to_recreate = _csb
   verify = proc {
    success = wait_for(60, interval: 9) {
      _csb.exists?
    }
    unless success
      raise "could not find the clusterrolebinding, see log"
    end
  }
   if after_scenario
    teardown_add verify
    step 'hidden recreate cluster resource after scenario'
  else
    step 'hidden recreate cluster resource'
    verify.call
  end
end
