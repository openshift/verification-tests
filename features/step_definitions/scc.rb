# creates a SCC policy and registers clean-up to remove it after scenario
Given /^the following scc policy is created: (.+)$/ do |policy|
  ensure_admin_tagged
  ensure_destructive_tagged

  if policy.include? '://'
    step %Q{I download a file from "#{policy}"}
    path = @result[:abs_path]
  else
    path = localhost.absolutize policy
  end

  raise "no policy template found: #{path}" unless File.exist?(path)

  ## figure out policy name for clean-up
  policy_name = YAML.load_file(path)["metadata"]["name"]
  raise "no policy name in template" unless policy_name

  @result = admin.cli_exec(:create, f: path)
  if @result[:success]
    step %Q/admin ensures "#{policy_name}" scc is deleted after scenario/
  else
    raise "unable to set scc policy #{path}, see log"
  end
end

# setup tear_down to restore scc after scenario ends
Given /^scc policy #{QUOTED} is restored after scenario$/ do |policy|
  ensure_admin_tagged
  ensure_destructive_tagged

  @result = admin.cli_exec(:get, resource: 'scc', resource_name: policy, o: 'yaml')
  if @result[:success]
    orig_policy = @result[:response]
    logger.info "SCC restore tear_down registered:\n#{orig_policy}"
  else
    raise "could not get scc: #{policy}"
  end
  orig_policy = @result[:parsed]
  orig_policy['metadata'].delete('resourceVersion')
  orig_policy['metadata'].delete('uid')
  orig_policy = orig_policy.to_json
  _admin = admin
  teardown_add {
    @result = _admin.cli_exec(
      :replace,
      f: "-",
      _stdin: orig_policy
    )
    raise "cannot restore #{policy}" unless @result[:success]
  }
end

Given /^SCC #{QUOTED} is (added to|removed from) the #{QUOTED} (user|group|service account)( without teardown)?$/ do |scc, op, which, type, no_teardown|
  ensure_admin_tagged
  if no_teardown
    ensure_upgrade_prepare_tagged
  end
  _admin = admin

  case type
  when "group"
    _add_command = :oadm_policy_add_scc_to_group
    _remove_command = :oadm_policy_remove_scc_from_group
    _opts = {scc: scc, group_name: which}
  when "user", "service account"
    _opts = {scc: scc}
    if type == "user"
      _user_name = user(word_to_num(which), switch: false).name
      _opts[:user_name] = _user_name
    else
      _user_name = service_account(which).full_id
      # _opts[:serviceaccount] = _user_name # this is project dependent
      _opts[:user_name] = _user_name
    end

    _add_command = :oadm_policy_add_scc_to_user
    _remove_command = :oadm_policy_remove_scc_from_user
  else
    raise "what is this subject type #{type}?!"
  end

  case op
  when "added to"
    _command = _add_command
    _teardown_command = _remove_command
  when "removed from"
    _command = _remove_command
    _teardown_command = _add_command
  else
    raise "unknown scc operation #{op}"
  end

  # we reattempt multiple times to workaround races where cluster policy is
  #   concurrently changed by another test executor
  wait_for(60, interval: 5) {
    @result = _admin.cli_exec(_command, **_opts)
    @result[:success]
  }
  if @result[:success]
    if no_teardown
      logger.warn "No teardown to restore SCC of #{which} #{type}"
    else
      teardown_add {
        _res = nil
        wait_for(60, interval: 5) {
          _res = _admin.cli_exec(_teardown_command, **_opts)
          _res[:success]
        }
        raise "could not restore SCC of #{which} #{type}" unless _res[:success]
      }
    end
  else
    raise "could not give #{which} #{type} the #{scc} scc"
  end
end
