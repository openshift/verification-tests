Given /^I deploy #{QUOTED} driver using csi(?: with "([^ ]+?)" version)?$/ do |driver, img_version|
  transform binding, :driver, :img_version
  ensure_admin_tagged
  ensure_destructive_tagged

  config_hash       = env.master_services[0].config.as_hash()
  imgformat         = config_hash["imageConfig"]["format"]
  img_registry      = imgformat.split("\/")[0]
  ose_version       = env.get_version(user:admin)
  img_version       = "v#{ose_version[0]}" unless img_version
  namespace         = "csi-#{driver}"
  serviceaccount    = "#{driver}-csi"
  registrar_image   = "#{img_registry}/openshift3/csi-driver-registrar:#{img_version}"
  attacher_image    = "#{img_registry}/openshift3/csi-attacher:#{img_version}"
  provisioner_image = "#{img_registry}/openshift3/csi-provisioner:#{img_version}"

  project(namespace)
  if project.exists?(user: admin)
    raise "project #{namespace} exists already."
  end

  # create namespace for csi driver
  ns_cmd = "oc adm new-project #{namespace} --node-selector=''"
  @result = env.master_hosts.first.exec(ns_cmd)
  step %Q/the step should succeed/

  # create serviceaccount for csi driver
  sa = service_account(serviceaccount)
  @result =  sa.create(by: admin)
  step %Q/the step should succeed/

  # add scc to serviceaccount
  _opts = {scc: "privileged", user_name: "system:serviceaccount:#{namespace}:#{serviceaccount}"}
  add_command = :oadm_policy_add_scc_to_user
  @result = admin.cli_exec(add_command, **_opts)
  step %Q/the step should succeed/


  sc= storage_class("#{driver}-csi")
  sc.ensure_deleted(user: admin)

  # create clusterrole, clusterrolebinding
  step %Q/admin ensures "#{driver}-csi-role" clusterrole is deleted/
  step %Q/admin ensures "#{driver}-csi-role" clusterrolebinding is deleted/
  step %Q/I run the :create admin command with:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/storage/csi/#{driver}-clusterrole.yaml |
  })
  step %Q/the step should succeed/

  step %Q{I obtain test data file "storage/csi/#{driver}-clusterrolebinding.yaml"}
  crb = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  crb["subjects"][0]["namespace"] = namespace
  File.write(filepath, crb.to_yaml)
  @result = admin.cli_exec(:create, f: filepath)
  step %Q/the step should succeed/

  # create secret
  step %Q/I run the :create admin command with:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/storage/csi/#{driver}-secrets.yaml |
    | n | #{namespace}                                                                                          |
  })
  step %Q/the step should succeed/

  # create Deployment
  step %Q{I obtain test data file "storage/csi/#{driver}-deployment.yaml"}
  deployment = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  deployment["spec"]["template"]["spec"]["containers"][0]["image"] = "#{attacher_image}"
  deployment["spec"]["template"]["spec"]["containers"][1]["image"] = "#{provisioner_image}"
  File.write(filepath, deployment.to_yaml)
  res = admin.cli_exec(:create, n: namespace, f: filepath)
  raise "error creating deployment for csi driver #{driver}" unless res[:success]

  # create Daemonset
  step %Q{I obtain test data file "storage/csi/#{driver}-daemonset.yaml"}
  daemonset = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  daemonset["spec"]["template"]["spec"]["containers"][0]["image"] = "#{registrar_image}"
  File.write(filepath, daemonset.to_yaml)
  res = admin.cli_exec(:create, n: namespace, f: filepath)
  raise "error creating daemonset for csi driver #{driver}" unless res[:success]
end

Given /^I cleanup #{QUOTED} csi driver$/ do |driver|
  transform binding, :driver
  ensure_admin_tagged
  ensure_destructive_tagged

  serviceaccount = "#{driver}-csi"

  # delete project
  step %Q/admin ensures "#{namespace}" project is deleted/

  # delete clusterrole, clusterrolebinding
  step %Q/I run the :delete admin command with:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/storage/csi/#{driver}-clusterrole.yaml |
  })
  step %Q/the step should succeed/
  step %Q/I run the :delete admin command with:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/storage/csi/#{driver}-clusterrolebinding.yaml |
  })
  step %Q/the step should succeed/

  # remove serviceaccount from scc
  step %Q/SCC "privileged" is removed from the "system:serviceaccount:#{namespace}:#{serviceaccount}" service account/
  step %Q/the step should succeed/

  # delete storage class
    step %Q/I run the :delete admin command with:/, table(%{
    | f | #{BushSlicer::HOME}/testdata/storage/csi/#{driver}-storageclass.yaml |
  })
  step %Q/the step should succeed/

end

Given /^I create (default )?storage class for #{QUOTED} csi driver$/ do |default_sc, driver|
  transform binding, :default_sc, :driver
  step %Q{I obtain test data file "storage/csi/#{driver}-storageclass.yaml"}
  sc = YAML.load(@result[:response])
  filepath = @result[:abs_path]

  if default_sc
    step %Q/default storage class is patched to non-default/
    sc["metadata"]["annotations"]["storageclass.kubernetes.io/is-default-class"] = "true"
  end
  File.write(filepath, sc.to_yaml)
  res = admin.cli_exec(:create, f: filepath)
  raise "error creating storage class for csi driver #{driver}" unless res[:success]
end

Given /^I checked #{QUOTED} csi driver is running$/ do |driver|
  transform binding, :driver
  ensure_admin_tagged
  ensure_destructive_tagged
  
  step %/I switch to cluster admin pseudo user/
  step %/I use the "csi-#{driver}" project/
  step %Q/I wait until number of replicas match "2" for deployment "#{driver}-csi-controller"/
  step %Q/"#{driver}-csi-ds" daemonset becomes ready in the project/

  dynamic_pvc_name = rand_str(8, :dns)
  step %Q{I run oc create over "#{BushSlicer::HOME}/testdata/storage/misc/pvc-with-storageClassName.json" replacing paths:}, table(%{
    | ["metadata"]["name"]         | #{dynamic_pvc_name} |
    | ["spec"]["storageClassName"] | #{driver}-csi       |
  })
  step %Q/the step should succeed/
  step %Q/the "#{dynamic_pvc_name}" PVC becomes :bound within 120 seconds/
end
