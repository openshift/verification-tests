# replicas related steps
#

## example usage Given there are 6 "daemon_set" replicas in the "openshift-monitoring" project
Given /^there are #{NUMBER} #{QUOTED} replicas in the #{QUOTED} project$/ do |expected, resource_type, namespace|
  ensure_admin_tagged
  expected = expected.to_i
  clazz = resource_class(resource_type)
  if BushSlicer::ProjectResource > clazz
    list = clazz.list(user: user, project: project(namespace))
  else
    list = clazz.list(user: user)
  end
  list.each do | cl |
    desired_count = cl.replica_counters(cached: false)[:desired]
    if desired_count != expected.to_i
      raise "#{resource_type} count is #{desired_count}, but is expected to be #{expected} instead"
    end
  end
end
