Given /^there are no PVs with local path #{QUOTED}$/ do | local_path |
  transform binding, :local_path
  ensure_admin_tagged

  pvs = BushSlicer::PersistentVolume.list(user: admin)
  pvs.each { |pv|
    if pv.local_path == local_path
       raise "There is a persistentvolume for local path:#{local_path}"
    end
  }
end

Given /^I get the log of local storage provisioner for node #{QUOTED}?$/ do |node_name|
  transform binding, :node_name
  ensure_admin_tagged

  pods = env.local_storage_provisioner_project.pods(by: admin)
  pod = pods.find {|p| p.node_name == node_name }
  raise "No pod is found for node:#{node_name}" unless pod

  @result = env.master_hosts[0].exec_admin("oc logs #{pod.name} -n #{env.local_storage_provisioner_project.name}")
end

Given /^I delete the local storage provisioner for node #{QUOTED}?$/ do |node_name|
  transform binding, :node_name
  ensure_admin_tagged
  ensure_destructive_tagged

  pods = env.local_storage_provisioner_project.pods(by: admin)
  pod = pods.find {|p| p.node_name == node_name }
  raise "No pod is found for node:#{node_name}" unless pod

  @result = env.master_hosts[0].exec_admin("oc delete pod #{pod.name} -n #{env.local_storage_provisioner_project.name}")
end
