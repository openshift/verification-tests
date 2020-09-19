Given(/^the "([^"]*)" descheduler CR is restored from the "([^"]*)" after scenario$/) do |name, project_name|
  ensure_admin_tagged
  ensure_destructive_tagged
  org_descheduler = {}
  @result = admin.cli_exec(:get, resource: 'kubedescheduler', resource_name: name, o: 'yaml', n: project_name)
  if @result[:success]
    org_descheduler['spec'] = @result[:parsed]['spec']
    logger.info "descheduler restore tear_down registered:\n#{org_descheduler}"
  else
    raise "Could not get descheduler: #{name}"
  end
  patch_json = org_descheduler.to_json
  _admin = admin
  teardown_add {
    opts = {resource: 'kubedescheduler', resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore descheduler: #{name}" unless @result[:success]
}
end 
