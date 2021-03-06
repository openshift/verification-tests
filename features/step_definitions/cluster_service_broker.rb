Given /^the #{QUOTED} cluster service broker is recreated( after scenario)?$/ do |name, after_scenario|
  transform binding, :name, :after_scenario
  _admin = admin
  _csb = cluster_service_broker(name)
  cb.cluster_resource_to_recreate = _csb

  verify = proc {
    success = wait_for(60, interval: 9) {
      _csb.describe[:response].include? "Successfully fetched catalog entries from broker"
    }
    unless success
      raise "could not see cluster service broker ready, see log"
    end
  }

  if after_scenario
    teardown_add verify
    step 'hidden recreate cluster resource after scenario'
  else
    step 'hidden recreate cluster resource after scenario'
    verify.call
  end
end

Given /^I save the first service broker registry prefix to#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  ensure_admin_tagged
  cb_name ||= :reg_prefix
  org_project = project(generate: false) rescue nil
  project('openshift-ansible-service-broker')
  cb[cb_name] = YAML.load(config_map('broker-config').value_of('broker-config', user: admin))['registry'].first['name']
  project(org_project&.name)
end

