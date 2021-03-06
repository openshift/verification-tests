Given /^the #{QUOTED} oauth CRD is restored after scenario$/ do |name|
  transform binding, :name
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
    sleep 60
  }
end

# extract the secret given a htpasswd spec name
Given /^the secret for #{QUOTED} htpasswd is stored in the#{OPT_SYM} clipboard$/ do |name, cb_name|
  transform binding, :name, :cb_name
  cb_name ||= :htpasswd_secret
  project('openshift-config')
  generated_htpasswd_name = o_auth('cluster').htpasswds[name]
  cb[cb_name] = secret(generated_htpasswd_name).value_of('htpasswd')
end
