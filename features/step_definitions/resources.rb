# This step shouldn't be called by in scenarios directly. It is only to help
# other steps to recreate cluster resources. That's why a special cookie
# needs to be set for it to be executable.
# Rational is that recreating cluster resources would usually require some
# verification that they are working properly. We can't predict what each
# type will require. Thus extracting common code here and leave resource type
# specific steps handle verification.
Given /^hidden recreate cluster resource( after scenario)?$/ do |after_scenario|
  ensure_destructive_tagged

  unless cb.cluster_resource_to_recreate
    raise "please don't use this step directly from scenario"
  end

  _resource = cb.cluster_resource_to_recreate
  cb.cluster_resource_to_recreate = nil

  _admin = admin
  _resource_struct = _resource.raw_resource(user: _admin).freeze

  p = proc {
    _resource.ensure_deleted
    res = _resource.class.create(by: _admin,
                                 spec: _resource_struct)
    if res[:success]
      cache_resources res[:resource]
    else
      raise "failed to create #{_resource.class}: #{res[:response]}"
    end
  }

  if after_scenario
    teardown_add p
  else
    p.call
  end
end

Given /^the #{QUOTED} (\w+) is recreated( by admin)? in the#{OPT_QUOTED} project after scenario$/ do |resource_name, resource_type, by_admin, project_name|
  if by_admin
    ensure_admin_tagged
    _user = admin
  else
    _user = user
  end
  _resource = resource(resource_name, resource_type, project_name: project_name)
  unless BushSlicer::ProjectResource > _resource.class
    raise "step only supports project resources, but #{_resource.class} is not"
  end

  _raw_resource = _resource.raw_resource(user: _user)
  teardown_add {
    _resource.ensure_deleted(user: _user)
    res = _resource.class.create(by: _user,
                                 project: _resource.project,
                                 spec: _raw_resource)
    if res[:success]
      cache_resources res[:resource]
    else
      raise "failed to create #{_resource.class}: #{res[:response]}"
    end
  }
end

# as resource you need to use a string that exists as a resource method in World
Given /^(I|admin) checks? that the #{QUOTED} (\w+) exists(?: in the#{OPT_QUOTED} project)?$/ do |who, name, resource_type, namespace|
  _user = who == "admin" ? admin : user

  resource = resource(name, resource_type, project_name: namespace)

  resource.get_checked(user: _user, quiet: false)
end

Given /^(I|admin) checks? that there are no (\w+)(?: in the#{OPT_QUOTED} project)?$/ do |who, resource_type, namespace|
  _user = who == "admin" ? admin : user

  clazz = resource_class(resource_type)
  if BushSlicer::ProjectResource > clazz
    list = clazz.list(user: _user, project: project(namespace))
  else
    list = clazz.list(user: _user)
  end

  unless list.empty?
    raise "found resources: #{list.map(&:name).join(', ')}"
  end
end

Given /^(I|admin) waits? for all (\w+) in the#{OPT_QUOTED} project to become ready(?: up to (\d+) seconds)?$/ do |by, type, project_name, timeout|
  timeout = timeout ? Integer(timeout) : 180
  _user = by == "admin" ? admin : user
  clazz = resource_class(type)

  unless BushSlicer::ProjectResource > clazz
    raise "#{clazz} is not a ProjectResource"
  end

  list = clazz.list(user: _user, project: project(project_name))
  cache_resources *list
  logger.info("#{clazz::RESOURCE}: #{list.map(&:name)}")

  start_time = monotonic_seconds
  results = list.map do |resource|
    passed_time = monotonic_seconds - start_time
    @result = resource.wait_till_ready(_user, timeout - passed_time)
    unless @result[:success]
      raise "#{clazz.name} #{resource.name} did not become ready within timeout"
    end
    @result
  end
  @result = BushSlicer::ResultHash.aggregate_results(results)
end

Given /^(I|admin) waits? for the#{OPT_QUOTED} (\w+) to become ready(?: in the#{OPT_QUOTED} project)?(?: up to (\d+) seconds)?$/ do |by, name, type, project_name, timeout|
  _user = by == "admin" ? admin : user
  _resource = resource(name, type, project_name: project_name)
  timeout = timeout ? timeout.to_i : 60


  logger.info("User: #{_user}")
  logger.info("Resource.name: #{_resource.name}")
  logger.info("Resource.project: #{_resource.project_name}")
  logger.info("Resource.type: #{_resource.type}")
  logger.info("Timeout: #{timeout}")

  unless _resource
    raise "Failed to get resource #{name} of type #{type} in project #{project_name}"
  end

  @result = _resource.wait_till_ready(_user, timeout)
  unless @result[:success]
    raise %Q{#{type} "#{_resource.name}" did not become ready within } \
       "#{timeout} seconds"
  end
end

# tries to delete resource if it exists and make sure it disappears
# example: I ensure "hello-openshift" pod is deleted
Given /^(I|admin) ensures? #{QUOTED} (\w+) is deleted(?: from the#{OPT_QUOTED} project)?(?: within (\d+) seconds)?( after scenario)?$/ do |by, name, type, project_name, timeout, after|
  _user = by == "admin" ? admin : user
  _resource = resource(name, type, project_name: project_name)
  _seconds = timeout ? timeout.to_i : 300
  p = proc {
    @result = _resource.ensure_deleted(user: _user, wait: _seconds)
  }

  if after
    teardown_add p
  else
    p.call
  end
end

# example: I wait for the "hello-pod" pod to appear up to 42 seconds
Given /^(I|admin) waits? for the #{QUOTED} (\w+) to appear(?: in the#{OPT_QUOTED} project)?(?: up to (\d+) seconds)?$/ do |by, name, type, project_name, timeout|
  _user = by == "admin" ? admin : user
  _resource = resource(name, type, project_name: project_name)
  timeout = timeout ? timeout.to_i : 60

  @result = _resource.wait_to_appear(_user, timeout)
  unless @result[:success]
    raise %Q{#{type} "#{name}" did not appear within timeout}
  end
end

Given /^the( admin)? (\w+) named #{QUOTED} does not exist(?: in the#{OPT_QUOTED} project)?$/ do |who, resource_type, resource_name, project_name|
  _user = who ? admin : user
  _resource = resource(resource_name, resource_type, project_name: project_name)
  _seconds = 60

  if _resource.exists?(user: _user)
    raise "#{resource_type} names #{resource_name} exists"
  end
end

# When applying "oc delete" on one resource, the resource may take some time to
# terminate, so use this step to wait for its dispapearing.
Given /^I wait for the resource "(.+)" named "(.+)" to disappear(?: within (\d+) seconds)?$/ do |resource_type, resource_name, timeout|
  opts = {resource_name: resource_name, resource: resource_type}
  res = {}
  # just put a timeout so we don't hang there indefintely
  timeout = timeout ? timeout.to_i : 15 * 60
  # TODO: update to use the new World#resource method
  success = wait_for(timeout) {
    res = user.cli_exec(:get, **opts)
    case res[:response]
    # the resource has terminated which means we are done waiting.
    when /Error from server \(Forbidden\): projects.project.openshift.io/, /not found/, /No resources found/
      break true

    end
  }
  res[:success] = success
  @result  = res
  unless @result[:success]
    logger.error(@result[:response])
    raise "#{resource_name} #{resource_type} did not terminate"
  end
end

Given /^#{WORD}( in the#{OPT_QUOTED} project)? with name matching #{RE} are stored in the#{OPT_SYM} clipboard$/ do |type, in_project, pr_name, pattern, cb_name|
  cb_name ||= "resources"
  re = Regexp.new(pattern)
  clazz = resource_class(type)
  list_opts = {user: user}

  if in_project && !(BushSlicer::ProjectResource > clazz)
    raise "#{clazz} is not a ProjectResource"
  elsif BushSlicer::ProjectResource > clazz
    list_opts[:project] = project(pr_name, generate: false)
  end

  list = clazz.list(**list_opts)
  logger.info("#{clazz::RESOURCE}: #{list.map(&:name)}")
  cb[cb_name] = list.select { |r| re =~ r.name }
  cache_resources *list
  cache_resources cb[cb_name].first if cb[cb_name].first
end

Given /^(I|admin) stores? all (\w+) in the#{OPT_QUOTED} project to the#{OPT_SYM} clipboard$/ do |who, type, namespace, cb_name|
  cb_name ||= :resources
  _user = who == "admin" ? admin : user

  clazz = resource_class(type)
  if BushSlicer::ProjectResource > clazz
    cb[cb_name] = clazz.list(user: _user, project: project(namespace))
  else
    cb[cb_name] = clazz.list(user: _user)
  end
end

Given /^(I|admin) stores? all (\w+) to the#{OPT_SYM} clipboard$/ do |who, type, cb_name|
  cb_name ||= :resources
  _user = who == "admin" ? admin : user

  clazz = resource_class(type)
  if BushSlicer::ProjectResource > clazz
    cb[cb_name] = clazz.list(user: _user, project: project)
  else
    cb[cb_name] = clazz.list(user: _user)
  end
end


Given /^I remove all #{WORD}(?: in the#{OPT_QUOTED} project) with labels:$/ do | resource_type, namespace, table |
  labels = table.raw.flatten
  namespace ||= project.name
  clazz = resource_class(resource_type)
  if BushSlicer::ProjectResource > clazz
    list = clazz.get_labeled(*labels, user: user, project: project(namespace))
  else
    ensure_destructive_tagged
    list = clazz.get_labeled(*labels, user: user)
  end
  list.each { |r| r.ensure_deleted }
end
