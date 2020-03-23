Given /^the #{QUOTED} scheduler priorityclasses is restored after scenario$/ do |name|
  _admin = admin
  teardown_add {
    opts = {object_type: 'priorityclasses', object_name_or_id: name}
    @result = _admin.cli_exec(:delete, **opts)
    raise "Cannot delete priorityclass: #{name}" unless @result[:success]
  }
end

Given /^the #{QUOTED} scheduler CR is restored after scenario$/ do |name|
  ensure_admin_tagged
  ensure_destructive_tagged
  org_scheduler = {}
  @result = admin.cli_exec(:get, resource: 'scheduler', resource_name: name, o: 'yaml')
  if @result[:success]
    org_scheduler['spec'] = @result[:parsed]['spec']
    logger.info "scheduler restore tear_down registered:\n#{org_scheduler}"
  else
    raise "Could not get scheduler: #{name}"
  end
  patch_json = org_scheduler.to_json
  _admin = admin
  teardown_add {
    opts = {resource: 'scheduler', resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore scheduler: #{name}" unless @result[:success]
  }
end

Given /^the #{QUOTED} clusterrole is restored after scenario$/ do |name|
  ensure_admin_tagged
  ensure_destructive_tagged
  patch_json = '[{"op": "remove", "path": "/rules/2/resourceNames/1"}]'
  _admin = admin
  teardown_add {
    opts = {resource: 'clusterrole', resource_name: name, p: patch_json, type: 'json'}
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore clusterrole: #{name}" unless @result[:success]
  }
end
