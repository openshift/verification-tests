require 'yaml'

Given /^CSI hostpath driver has been installed successfully$/ do
  ensure_admin_tagged
  namespace = "csihostpath"
  cb.version = cluster_version('version').channel.split('-')[1]
  unless project(namespace).exists?
  step %Q/I run the :oadm_new_project admin command with:/, table(%{
    | project_name  | #{namespace} |
  })
  end

  step %Q/I use the "#{namespace}" project/
  step %Q/I obtain test data file "storage\/csi\/#{cb.version}\/csi-rbac.yaml"/
  step %Q/I run the :apply client command with:/, table(%{
    | f | csi-rbac.yaml |
  })
  step %Q/the step should succeed/
  
  step %Q/SCC "privileged" is added to the "csi-provisioner" service account/
  step %Q/SCC "privileged" is added to the "csi-attacher" service account/
  step %Q/SCC "privileged" is added to the "csi-snapshotter" service account/
  step %Q/SCC "privileged" is added to the "csi-plugin" service account/
  step %Q/SCC "privileged" is added to the "csi-resizer" service account/

  step %Q/I obtain test data file "storage\/csi\/#{cb.version}\/csi-pods.yaml"/

  step %Q/I run the :apply client command with:/, table(%{
    | f | csi-pods.yaml |
  })
  step %Q/the step should succeed/

  case 
  when env.version_ge("4.4", user: user)
    pod_num = 5
  when env.version_eq("4.3", user: user)
    pod_num = 4
  when env.version_eq("4.2", user: user)
    pod_num = 3
  end
  step %Q/#{pod_num} pods become ready with labels:/, table(%{
      | test=csi-test |
  })
end

  





