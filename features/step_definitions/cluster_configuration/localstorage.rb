# OCP supports fileystem local storage provisioner from 3.7
# For some OCP versions, before depolying local storage provisoner,
# we need enable some feature gates first.
# ref: doc/storage_automation_spec.adoc

Given /^I deploy local storage provisioner(?: with "([^ ]+?)" version)?$/ do |img_version|
  transform binding, :img_version
  ensure_admin_tagged
  ensure_destructive_tagged

  namespace = env.local_storage_provisioner_project.name
  config_hash = env.master_services[0].config.as_hash()
  imgformat = config_hash["imageConfig"]["format"]
  img_registry = imgformat.split("\/")[0]
  ose_version = env.get_version(user: admin)
  img_version = "v#{ose_version[0]}" unless img_version
  serviceaccount="local-storage-admin"
  configmap="local-volume-config"
  template="local-storage-provisioner"
  image="#{img_registry}/openshift3/local-storage-provisioner:#{img_version}"
  path ||="/mnt/local-storage"
  cmurl = "#{BushSlicer::HOME}/testdata/storage/localvolume/configmap-37.yaml"
  if env.version_ge("3.10", user: user)
    cmurl = "#{BushSlicer::HOME}/testdata/storage/localvolume/configmap.yaml"
  end

  project(namespace)
  # if project exists, delete project and pvs created by local storage provisioner
  if project.exists?(user: admin)
    project.delete(by: admin)
    project.wait_to_disappear(admin)

    BushSlicer::PersistentVolume.list(user: admin).each { |pv|
      pv.delete(by: admin) if pv.name.start_with?("local-pv-") && (pv.local_path&.start_with?("#{path}/fast") || pv.local_path&.start_with?("#{path}/slow"))
    }
  end

  ns_cmd = "oc adm new-project #{namespace} --node-selector=''"
  @result = env.master_hosts.first.exec(ns_cmd)
  step %Q/the step should succeed/

  env.hosts.each do |host|
    setup_commands = [
      "mkdir -p #{path}/fast/vol1",
      "mount -t tmpfs fvol1 #{path}/fast/vol1",
      "mkdir -p #{path}/fast/vol2",
      "mount -t tmpfs fvol2 #{path}/fast/vol2",
      "mkdir -p #{path}/slow/vol1",
      "mount -t tmpfs svol1 #{path}/slow/vol1",
      "mkdir -p #{path}/slow/vol2",
      "mount -t tmpfs svol2 #{path}/slow/vol2",
      "chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 #{path}"
    ]
    res = host.exec_admin(*setup_commands)
    raise "error preaparing subdirs for local storage provisioner" unless res[:success]
  end

  step %Q/I download a file from "#{cmurl}"/
  cfm = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  if env.version_ge("3.10", user: user)
    cfm["data"]["storageClassMap"].gsub!("/mnt/local-storage", path)
  else
    cfm["data"]["local-fast"].gsub!("/mnt/local-storage", path)
    cfm["data"]["local-slow"].gsub!("/mnt/local-storage", path)
  end
  File.write(filepath, cfm.to_yaml)
  res = admin.cli_exec(:create, n: namespace, f: filepath)
  raise "error creating configmap for local storage provisioner" unless res[:success]

  step %Q/I switch to cluster admin pseudo user/
  sa = service_account(serviceaccount)
  @result =  sa.create(by: admin)
  step %Q/the step should succeed/

  _opts = {scc: "privileged", user_name: "system:serviceaccount:#{namespace}:#{serviceaccount}"}
  add_command = :oadm_policy_add_scc_to_user
  @result = admin.cli_exec(add_command, **_opts)
  step %Q/the step should succeed/

  step %Q/I run the :create admin command with:/, table(%{
      | f | https://raw.githubusercontent.com/openshift/origin/release-3.9/examples/storage-examples/local-examples/local-storage-provisioner-template.yaml |
      | n | #{namespace}                                                                                                                                    |
  })
  step %Q/the step should succeed/

  step 'admin ensures "local-storage:provisioner-node-binding" clusterrolebinding is deleted'
  step 'admin ensures "local-storage:provisioner-pv-binding" clusterrolebinding is deleted'
  step %Q/I run the :new_app admin command with:/, table(%{
      | param    | CONFIGMAP=#{configmap}            |
      | param    | SERVICE_ACCOUNT=#{serviceaccount} |
      | param    | NAMESPACE=#{namespace}            |
      | param    | PROVISIONER_IMAGE=#{image}        |
      | template | #{template}                       |
      | n        | #{namespace}                      |
  })
  step %Q/the step should succeed/

  nodes = env.nodes.select { |n| n.schedulable? }
  step %/#{nodes.size} pods become ready with labels:/, table(%{
      | app=local-volume-provisioner|
  })

  pv_count = 0
  BushSlicer::PersistentVolume.list(user: admin).each { |pv|
    if pv.name.start_with?("local-pv-") && (pv.local_path&.start_with?("#{path}/fast") || pv.local_path&.start_with?("#{path}/slow"))
      pv_count += 1
    end
  }

  raise "error creating PVs with local storage provisioner" unless (pv_count == nodes.size * 4)

  lf_sc = storage_class("local-fast")
  lf_sc.ensure_deleted(user: admin)
  ls_sc = storage_class("local-slow")
  ls_sc.ensure_deleted(user: admin)

  step %Q{I obtain test data file "storage/misc/storageClass.yaml"}
  sc = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  sc["metadata"]["name"] = "local-fast"
  sc["provisioner"] = "kubernetes.io/no-provisioner"
  sc["volumeBindingMode"] = "Immediate"
  File.write(filepath, sc.to_yaml)
  @result = admin.cli_exec(:create, f: filepath)
  step %Q/the step should succeed/

  sc["metadata"]["name"] = "local-slow"
  File.write(filepath, sc.to_yaml)
  @result = admin.cli_exec(:create, f: filepath)
  step %Q/the step should succeed/
end

# local raw block devices provisioner is supported from OCP 3.10
# Before deploy this provisioner, feature gate "BlockVolume" needs enable first.
Given /^I deploy local raw block devices provisioner(?: with "([^ ]+?)" version)?$/ do |img_version|
  transform binding, :img_version
  ensure_admin_tagged
  ensure_destructive_tagged

  namespace = "#{env.local_storage_provisioner_project.name}-block"
  config_hash = env.master_services[0].config.as_hash()
  imgformat = config_hash["imageConfig"]["format"]
  img_registry = imgformat.split("\/")[0]
  ose_version = env.get_version(user: admin)
  img_version = "v#{ose_version[0]}" unless img_version
  serviceaccount="local-storage-admin"
  configmap="local-volume-config"
  template="local-storage-provisioner"
  image="#{img_registry}/openshift3/local-storage-provisioner:#{img_version}"
  path ||="/mnt/local-storage"

  project(namespace)
  # if project exists, delete project and pvs created by local storage provisioner
  if project.exists?(user: admin)
    project.delete(by: admin)

    BushSlicer::PersistentVolume.list(user: admin).each { |pv|
      pv.delete(by: admin) if pv.name.start_with?("local-pv-") && pv.local_path&.start_with?("#{path}/block-devices")
    }
  end

  ns_cmd = "oc adm new-project #{namespace} --node-selector=''"
  @result = env.master_hosts.first.exec(ns_cmd)
  step %Q/the step should succeed/

  env.hosts.each do |host|
    setup_commands = [
      "losetup -d /dev/loop23 /dev/loop24",
      "rm -rf #{path}/block-devices",
      "mkdir -p #{path}/block-devices",
      "dd if=/dev/zero of=#{path}/block-devices/dev1 bs=1M count=100",
      "dd if=/dev/zero of=#{path}/block-devices/dev2 bs=1M count=100",
      "losetup /dev/loop23 --show #{path}/block-devices/dev1",
      "losetup /dev/loop24 --show #{path}/block-devices/dev2",
      "ln -s /dev/loop23 #{path}/block-devices/ldev1",
      "ln -s /dev/loop24 #{path}/block-devices/ldev2",
      "chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /dev/loop23 /dev/loop24",
      "chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 #{path}"
    ]
    res = host.exec_admin(*setup_commands)
    raise "error preaparing subdirs for local storage provisioner" unless res[:success]
  end

  step %Q{I obtain test data file "storage/localvolume/configmap.yaml"}
  cfm = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  cfm["data"]["storageClassMap"].gsub!(/local-slow\D+/, "")
  cfm["data"]["storageClassMap"].gsub!(/local-fast/, "block-devices")
  cfm["data"]["storageClassMap"].gsub!(/\/mnt\/local-storage\S+/, "#{path}/block-devices")
  File.write(filepath, cfm.to_yaml)
  res = admin.cli_exec(:create, n: namespace, f: filepath)
  raise "error creating configmap for local raw block devices storage provisioner" unless res[:success]

  step %Q/I switch to cluster admin pseudo user/
  sa = service_account(serviceaccount)
  @result =  sa.create(by: admin)
  step %Q/the step should succeed/

  _opts = {scc: "privileged", user_name: "system:serviceaccount:#{namespace}:#{serviceaccount}"}
  add_command = :oadm_policy_add_scc_to_user
  @result = admin.cli_exec(add_command, **_opts)
  step %Q/the step should succeed/

  step %Q/I run the :create admin command with:/, table(%{
      | f | #{BushSlicer::HOME}/testdata/storage/localvolume/local-block-template.yaml |
      | n | #{namespace}                                                                                                     |
  })
  step %Q/the step should succeed/

  step 'admin ensures "local-block:provisioner-node-binding" clusterrolebinding is deleted'
  step 'admin ensures "local-block:provisioner-pv-binding" clusterrolebinding is deleted'
  step %Q/I run the :new_app admin command with:/, table(%{
      | param    | CONFIGMAP=#{configmap}            |
      | param    | SERVICE_ACCOUNT=#{serviceaccount} |
      | param    | NAMESPACE=#{namespace}            |
      | param    | PROVISIONER_IMAGE=#{image}        |
      | template | #{template}                       |
      | n        | #{namespace}                      |
  })
  step %Q/the step should succeed/

  nodes = env.nodes.select { |n| n.schedulable? }
  step %/#{nodes.size} pods become ready with labels:/, table(%{
      | app=local-volume-provisioner|
  })

  pv_count = 0
  BushSlicer::PersistentVolume.list(user: admin).each { |pv|
    pv_count += 1 if pv.name.start_with?("local-pv-") && (pv.local_path&.start_with?("#{path}/block-devices"))
  }

  raise "error creating PVs with local raw block devices storage provisioner" unless (pv_count == nodes.size * 2)

  lf_sc = storage_class("block-devices")
  lf_sc.ensure_deleted(user: admin)

  step %Q{I obtain test data file "storage/misc/storageClass.yaml"}
  sc = YAML.load(@result[:response])
  filepath = @result[:abs_path]
  sc["metadata"]["name"] = "block-devices"
  sc["provisioner"] = "kubernetes.io/no-provisioner"
  sc["volumeBindingMode"] = "WaitForFirstConsumer"
  File.write(filepath, sc.to_yaml)
  @result = admin.cli_exec(:create, f: filepath)
  step %Q/the step should succeed/
end
