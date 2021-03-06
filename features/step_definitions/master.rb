# steps which interact with master-config.yaml file.

Given /^master config is merged with the following hash:$/ do |yaml_string|
  transform binding, :yaml_string
  ensure_destructive_tagged

  env.master_services.each { |service|
    service_config = service.config
    service_config.merge! yaml_string

    teardown_add {
      service_config.restore
    }
  }
end

Given /^master config is restored from backup$/ do
  @result = BushSlicer::ResultHash.aggregate_results(
    *env.master_services.map { |s| s.config.restore() }
  )
end

#Given(/^admin will download the master config to "(.+?)" file$/) do |file|
#  @result = BushSlicer::MasterConfig.raw(env)
#  if @result[:success]
#    file = File.join(localhost.workdir, file)
#    File.write(file, @result[:response])
#  end
#end

#Given(/^admin will update master config from "(.+?)" file$/) do |file|
#  BushSlicer::MasterConfig.backup(env)
#  content = File.read(File.expand_path(file))
#  @result = BushSlicer::MasterConfig.update(env, content)

#  teardown_add {
#    BushSlicer::MasterConfig.restore(env)
#  }
#end

Given /^the value with path #{QUOTED} in master config is stored into the#{OPT_SYM} clipboard$/ do |path, cb_name|
  transform binding, :path, :cb_name
  ensure_admin_tagged
  config_hash = env.master_services[0].config.as_hash()
  cb_name ||= "config_value"
  cb[cb_name] = eval "config_hash#{path}"
end

Given /^the master service is restarted on all master nodes( after scenario)?$/ do |after|
  transform binding, :after
  ensure_destructive_tagged

  _master_services = env.master_services
  p = proc {
    _master_services.each { |service|
      service.restart(raise: true)
    }
  }

  if after
    teardown_add p
  else
    p.call
  end
end

Given /^I try to restart the master service on all master nodes$/ do
  ensure_destructive_tagged
  results = []

  env.master_services.each { |service|
    results.push(service.restart)
  }
  @result = BushSlicer::ResultHash.aggregate_results(results)
end

Given /^I use the first master host$/ do
  ensure_admin_tagged
  @host = env.master_hosts.first
end

Given /^I run commands on all masters:$/ do |table|
  transform binding, :table
  ensure_admin_tagged
  @result = BushSlicer::ResultHash.aggregate_results env.master_hosts.map { |host|
    host.exec_admin(table.raw.flatten)
  }
end

Given /^the master is operational$/ do
  ensure_admin_tagged
  success = wait_for(60) {
    admin.cli_exec(:get, resource_name: "default", resource: "project")[:success]
  }
  raise "Timed out waiting for master to become functional." unless success
end

Given /^the etcd version is stored in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  ensure_admin_tagged
  cb_name ||= :etcd_version
  # get etcd version depending if we have that executable installed or not
  @result = env.master_hosts.first.exec("etcd --version")
  if @result[:success]
    etcd_regex = /etcd Version:\s+(.+)$/
  else
    etcd_regex = /etcd (.+)$/
    @result = env.master_hosts.first.exec('openshift version')
  end
  etcd_version = @result[:response].match(etcd_regex)[1]
  raise "Can not retrieve the etcd version" if etcd_version.nil?
  cb[cb_name] = etcd_version
end

Given /^the #{QUOTED} path is( recursively)? removed on all masters after scenario$/ do |path, recursively|
  transform binding, :path, :recursively
  @result = env.master_hosts.reverse_each { |host|
    @host = host
    step %{the "#{path}" path is#{recursively} removed on the host after scenario}
  }
end
