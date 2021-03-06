Given /the #{QUOTED} applied_cluster_resource_quota is stored in the#{OPT_QUOTED} clipboard/ do |type, cb_name|
  transform binding, :type, :cb_name
  cb_name ||= "acrq"
  list = BushSlicer::AppliedClusterResourceQuota.list(user: user, project: project)
  cb["#{cb_name}-list"] = list
  cb[cb_name] = list.find { |o| o.name.end_with?("-#{type}") }
end
