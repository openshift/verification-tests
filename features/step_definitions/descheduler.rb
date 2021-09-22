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
    @result = admin.cli_exec(:get, resource: 'kubedescheduler', resource_name: name, o: 'yaml')
    if @result[:success] and @result[:parsed]['spec']['profileCustomizations']
      patch_pc_json = [{"op": "remove","path": "/spec/profileCustomizations"}].to_json
      opts_pc = {resource: 'kubedescheduler', resource_name: name, p: patch_pc_json, type: 'json' }
      @result_pc = _admin.cli_exec(:patch, **opts_pc)
      rasie "Cannot restore profileCustomizations" unless @result_pc[:success]
      opts = {resource: 'kubedescheduler', resource_name: name, p: patch_json, type: 'merge' }
    end
    opts = {resource: 'kubedescheduler', resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore descheduler: #{name}" unless @result[:success]
}
end 
