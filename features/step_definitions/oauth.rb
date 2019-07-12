Given /^the #{QUOTED} oauth CRD is restored after scenario$/ do |name|
  ensure_admin_tagged
  org_oauth = {}
  @result = admin.cli_exec(:get, resource: 'oauth', resource_name: name, o: 'yaml')
  if @result[:success]
    org_oauth['spec'] = @result[:parsed]['spec']
    logger.info "OAuth restore tear_down registered:\n#{org_oauth}"
  else
    raise "Could not get OAuth: #{name}"
  end
  patch_json = org_oauth.to_json
  _admin = admin
  teardown_add {
    opts = {resource: 'oauth', resource_name: name, p: patch_json, type: 'merge' }
    @result = _admin.cli_exec(:patch, **opts)
    raise "Cannot restore OAuth: #{name}" unless @result[:success]
  }
end
