# helper step to get default router subdomain
# will create a dummy route to obtain that
# somehow hacky in all regardsm hope we obtain a better mechanism after some time
Given /^I store default router subdomain in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  if env.is_admin? user
    raise "get router info as regular user"
  end

  cb_name = 'tmp' unless cb_name
  cb[cb_name] = env.router_default_subdomain(user: user,
                                             project: project(generate: false))
  logger.info cb[cb_name]
end

Given /^I store default router IPs in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  if env.is_admin? user
    raise "get router info as regular user"
  end

  cb_name = 'ips' unless cb_name
  cb[cb_name] = env.router_ips(user: user, project: project(generate: false))
  logger.info cb[cb_name]
end

Given /^default (docker-registry|router) replica count is stored in the#{OPT_SYM} clipboard$/ do |resource ,cb_name|
  transform binding, :resource, :cb_name
  ensure_admin_tagged

  cb_name = 'replicas' unless cb_name
  _dc = dc(resource, project("default", switch: false))

  cb[cb_name] = _dc.replicas(user: admin)
  logger.info "default #{resource} has replica count of: #{cb[cb_name]}"
end
# example output... ["3.10.0-0.15.0", 3, 10]  we are only intersted in the elements [1] and [2]
Given /^I store master major version in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  cb_name = 'master_version' unless cb_name
  full_version, major, minor = env.get_version(user: user)
  cb[cb_name] = major.to_s + "." + minor.to_s
  logger.info "Master Version: " + cb[cb_name]
end

Given /^I store master image version in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  ensure_admin_tagged
  hosts = step "I select a random node's host"
  res = host.exec_admin("docker images")

  cb[cb_name] = res[:response].match(/\w*[origin|ose]-pod\s+(v\d+(?:[.-]\d+){2,6})/).captures[0]

  # for origin, return the :latest as image tag version
  if cb[cb_name].start_with?('1')
    cb[cb_name] = "latest"
  end
  logger.info "Master Image Version: " + cb[cb_name]
end

# compares environment version to given version string;
# only major and minor version is compared, i.e. "3.3" === "3.3.7";
# Origin style versions (e.g. 1.x) can be compared properly to OCP style
#   versions (e.g. 3.x); Such that "3.4" === "1.4";
# Example: Given the master version >= "3.4"
Given /^the master version ([<>=]=?) #{QUOTED}$/ do |op, ver|
  transform binding, :op, :ver
  unless env.version_cmp(ver, user: user).send(op.to_sym, 0)
    raise "master version not #{op} #{ver}"
  end
end

Given /^the cluster is running on OpenStack$/ do
  ensure_admin_tagged
  hosts = step "I select a random node's host"
  @result = host.exec_admin("ls /etc/origin/cloudprovider/")

  if cloud_type = @result[:response].include?("openstack")
    logger.info "The cluster is running on OpenStack"
  else
    raise "Case can be executed on OpenStack only"
  end
end

