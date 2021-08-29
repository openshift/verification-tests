Given /^the #{QUOTED} oauth CR is restored after scenario$/ do |name|
  ensure_admin_tagged
  @result = admin.cli_exec(:get, resource: 'oauth', resource_name: name, o: 'yaml')
  if @result[:success]
    org_oauth = @result[:parsed]
    # must remove resourceVersion, otherwise replace will fail with "Operation cannot be fulfilled ..."
    org_oauth['metadata'].delete('resourceVersion')

    org_oauth['metadata'].delete('managedFields')
    org_oauth['metadata'].delete('creationTimestamp')
    org_oauth['metadata'].delete('generation')
    org_oauth['metadata'].delete('uid')
    logger.info "OAuth restore tear_down registered:\n#{org_oauth}"
  else
    raise "Could not get OAuth: #{name}"
  end
  org_oauth_json = org_oauth.to_json
  _admin = admin
  teardown_add {
    puts "Original CR to restore:", org_oauth_json
    # Use replace instead of patch, otherwise the patch with org_oauth_json can only add or modify fields, but will not remove fields that were added
    @result = _admin.cli_exec(:replace, f: "-", _stdin: org_oauth_json)
    raise "Cannot restore OAuth: #{name}" unless @result[:success]
    sleep 60
  }
end

# extract the secret given a htpasswd spec name
Given /^the secret for #{QUOTED} htpasswd is stored in the#{OPT_SYM} clipboard$/ do |name, cb_name|
  cb_name ||= :htpasswd_secret
  project('openshift-config')
  generated_htpasswd_name = o_auth('cluster').htpasswds[name]
  cb[cb_name] = secret(generated_htpasswd_name).value_of('htpasswd')
end

# this step must be used immediately after the config changes, if place it after several steps of the changes,
# "Progressing" may be quickly changed from False to True and quickly changed to False then, which will make this step definition fail
Given /^authentication successfully rolls out after config changes$/ do
  ensure_admin_tagged
  interval_time = 5
  timeout = 300 # set 300 seconds here due to https://bugzilla.redhat.com/show_bug.cgi?id=1958198, after the bug fixed, the seconds should be reduced accordingly
  stats = {}
  error = nil
  step %Q/operator "authentication" becomes progressing within #{timeout} seconds/
  step %Q|operator "authentication" becomes available/non-progressing/non-degraded within #{timeout} seconds|
  success = wait_for(timeout, interval: interval_time, stats: stats){
    begin
      step %Q/I run the :get admin command with:/, table(%{
          | resource | pod                      |
          | l        | app=oauth-openshift      |
          | n        | openshift-authentication |
          })
      step %Q/the step should succeed/
      step %Q/the output should not contain "Terminating"/
      true
    rescue => e
      error = e
      false
    end
  }
  raise error unless success
end

