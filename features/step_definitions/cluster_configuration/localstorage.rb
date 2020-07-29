Given /^local storage operator has been installed successfully$/ do
  ensure_admin_tagged
  namespace = "openshift-local-storage"
  name = "local-storage"

  # create namespace
  unless project(namespace).exists?
    step %Q/I run the :oadm_new_project admin command with:/, table(%{
      | project_name  | #{namespace} |
    })
    step %Q/the step should succeed/
  end

  # create operator group
  step %Q/I use the "#{namespace}" project/
  unless operator_group(name).exists?
    step %Q/I obtain test data file "storage\/localvolume\/operatorgroup.yaml"/
    step %Q/I run oc create over "operatorgroup.yaml" replacing paths:/, table(%{
      | ["metadata"]["name"]           | #{name}      |
      | ["metadata"]["namespace"]      | #{namespace} |
      | ["spec"]["targetNamespaces"][0]| #{namespace} |
    })
    raise "Create OperatorGroup #{name} failed" unless @result[:success]
  end

  # get channel
  step %Q/evaluation of `cluster_version('version').channel.split('-')[1]` is stored in the :channel clipboard/

  # create subscription
  unless subscription("#{name}").exists?
    step %Q/I obtain test data file "storage\/localvolume\/sub.yaml"/
    step %Q/I run oc create over "sub.yaml" replacing paths:/, table(%{
      | ["metadata"]["name"] | #{name}         |
      | ["spec"]["channel"]  | "#{cb.channel}" |
    })
    raise "Create subscription #{name} failied" unless @result[:success]
  end

  # check status
  step %Q/a pod becomes ready with labels:/, table(%{
    | name=local-storage-operator |
  })
  raise "No pod is running for local storage operator" unless @result[:success]

  logger.info(" local storage operator is installed successfully in #{namespace} namespace")
end

Given /^local storage provisioner has been installed successfully$/ do
  ensure_admin_tagged
  namespace = "openshift-local-storage"
  name = "local-storage"

  step %Q/I use the "#{namespace}" project/
  # create localvolume
  unless local_volume("#{name}").exists?
    step %Q/I obtain test data file "storage\/localvolume\/localvolume.yaml"/
    step %Q/I run oc create over "localvolume.yaml" replacing paths:/, table(%{
      | ["metadata"]["name"]                                   | #{name}      |
      | ["metadata"]["namespace"]                              | #{namespace} |
      | ["spec"]["storageClassDevices"][0]["storageClassName"] | #{name}      |
    })
    raise "Create localvolume #{name} failied" unless @result[:success]
  end

  # check ds status
  step %Q/I store the nodes in the :nodes clipboard/
  step %Q/#{cb.nodes.count} pods become ready with labels:/, table(%{
      | app=local-volume-diskmaker-local-storage |
  })
  step %Q/#{cb.nodes.count} pods become ready with labels:/, table(%{
      | app=local-volume-provisioner-local-storage |
  })

  unless storage_class("#{name}").exists?
    raise "Create storageclass #{name} failed"
  end
end

Given /^some local storage PVs are created successfully$/ do
  ensure_admin_tagged

  step %Q/I store the schedulable workers in the :nodes clipboard/
  step %Q/I run commands on the nodes in the :nodes clipboard:/, table(%{
      | mkdir -p /srv/block-devices                                                                                         |
      | if [ ! -e /srv/block-devices/dev1 ]; then dd if=/dev/zero of=/srv/block-devices/dev1 bs=1M count=100 seek=30000; fi |
      | if [ ! -e /dev/loop23 ]; then losetup /dev/loop23 --show /srv/block-devices/dev1; fi                                |
  })

  # check PVs are created
  @result = BushSlicer::PersistentVolume.wait_for_labeled("storage.openshift.com/local-volume-owner-name=local-storage", user: admin, seconds: 2 * 60)
  if @result[:matching].count != cb.nodes.count
    raise "Create PVs failed"
  end

end
