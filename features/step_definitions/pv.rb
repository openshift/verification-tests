require 'yaml'

Given /^I save volume id from PV named "([^"]*)" in the#{OPT_SYM} clipboard$/ do |resource_name, cbname|
  cbname = 'volume' unless cbname
  ensure_admin_tagged
  step %Q/I run the :get admin command with:/, table(%{
    | resource      | pv               |
    | resource_name | #{resource_name} |
    | o             | yaml             |
  })
  step %Q/the step should succeed/
  @result[:parsed] = YAML.load @result[:response]
  case
  when @result[:parsed]['spec']['gcePersistentDisk']
    cb[cbname] = @result[:parsed]['spec']['gcePersistentDisk']['pdName']
  when @result[:parsed]['spec']['awsElasticBlockStore']
    cb[cbname] = @result[:parsed]['spec']['awsElasticBlockStore']['volumeID']
  when @result[:parsed]['spec']['cinder']
    cb[cbname] = @result[:parsed]['spec']['cinder']['volumeID']
  when @result[:parsed]['spec']['glusterfs']
    cb[cbname] = @result[:parsed]['spec']['glusterfs']['path'].gsub('vol_', '')
  when @result[:parsed]['spec']['azureDisk']
    cb[cbname] = @result[:parsed]['spec']['azureDisk']['diskURI']
  when @result[:parsed]['spec']['vsphereVolume']
    cb[cbname] = @result[:parsed]['spec']['vsphereVolume']['volumePath']
  when @result[:parsed]['spec']['rbd']
    cb[cbname] = @result[:parsed]['spec']['rbd']['image']
  when @result[:parsed]['spec']['csi']
    cb[cbname] = @result[:parsed]['spec']['csi']['volumeHandle']
  else
    raise "Unknown persistent volume type."
  end
end

Given /^I have a(?: (\d+) GB)? volume and save volume id in the#{OPT_SYM} clipboard$/ do |size, cbname|
  timeout = 60
  size = size ? size.to_i : 1
  cbname = 'volume_id' unless cbname
  ensure_admin_tagged
  unless project.exists?(user: user)
    raise "No project exist"
  end

  cb.dynamic_pvc_name = rand_str(8, :dns)
  step %Q{I create a dynamic pvc from "#{BushSlicer::HOME}/testdata/storage/misc/pvc.json" replacing paths:}, table(%{
    | ["metadata"]["name"]                         | <%= project.name %>-<%= cb.dynamic_pvc_name %> |
    | ["spec"]["resources"]["requests"]["storage"] | #{size}Gi                                      |
    })
  step %Q/the step should succeed/
  step %Q{I run oc create over "#{BushSlicer::HOME}/testdata/storage/misc/pod.yaml" replacing paths:}, table(%{
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | <%= project.name %>-<%= cb.dynamic_pvc_name %> |
      | ["metadata"]["name"]                                         | <%= project.name %>-mypod                      |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/test                                      |
   })
  step %Q/the "<%= project.name %>-<%= cb.dynamic_pvc_name %>" PVC becomes :bound within #{timeout} seconds/
  step %Q/I ensure "<%= project.name %>-mypod" pod is deleted/
  step %Q/admin ensures "<%= pvc.volume_name %>" pv is deleted after scenario/
  step %Q/I save volume id from PV named "<%= pvc.volume_name %>" in the :#{cbname} clipboard/
end

Given /^the#{OPT_QUOTED} PV becomes #{SYM}(?: within (\d+) seconds)?$/ do |pv_name, status, timeout|
  timeout = timeout ? timeout.to_i : 30
  @result = pv(pv_name).wait_till_status(status.to_sym, admin, timeout)

  unless @result[:success]
    raise "PV #{pv_name} never reached status: #{status}"
  end
end

#This is new step to obtain an volume id from storage class dynamic provision
Given /^I have a(?: (\d+) GB)? volume from provisioner "([^"]*)" and save volume id in the#{OPT_SYM} clipboard$/ do |size, provisioner, cbname|
  timeout = 120
  size = size ? size.to_i : 1
  cbname = 'volume_id' unless cbname
  ensure_admin_tagged
  unless project.exists?(user: user)
    raise "No project exist"
  end
  cb.dynamic_pvc_name = rand_str(8, :dns)
  cb.storage_class_name = rand_str(8, :dns)
  step %Q{admin creates a StorageClass from "#{BushSlicer::HOME}/testdata/storage/misc/storageClass.yaml" where:}, table(%{
    | ["metadata"]["name"] | <%= project.name %>-<%=cb.storage_class_name%> |
    | ["provisioner"]      | kubernetes.io/#{provisioner}                   |
    })
  step %Q/the step should succeed/
  step %Q{I create a dynamic pvc from "#{BushSlicer::HOME}/testdata/storage/azure/azpvc-sc.yaml" replacing paths:}, table(%{
    | ["metadata"]["name"]                         | <%= project.name %>-<%= cb.dynamic_pvc_name %> |
    | ["spec"]["resources"]["requests"]["storage"] | #{size}Gi                                      |
    | ["spec"]["storageClassName"]                 | <%= project.name %>-<%=cb.storage_class_name%> |
    })
  step %Q/the step should succeed/
  step %Q/the "<%= project.name %>-<%= cb.dynamic_pvc_name %>" PVC becomes :bound within #{timeout} seconds/
  step %Q/admin ensures "<%= pvc.volume_name %>" pv is deleted after scenario/
  step %Q/I save volume id from PV named "<%= pvc.volume_name %>" in the :#{cbname} clipboard/
end

Given /^the PVs become #{SYM}(?: within (\d+) seconds) with labels:?$/ do |status, timeout, table|
  timeout = timeout ? timeout.to_i : 30
  @result = pv(pv_name).wait_till_status(status.to_sym, admin, timeout)

  unless @result[:success]
    raise "PV #{pv_name} never reached status: #{status}"
  end
end

Given /^([0-9]+) PVs become #{SYM}(?: within (\d+) seconds)? with labels:$/ do |count, status, timeout, table|
  labels = table.raw.flatten # dimentions irrelevant
  timeout = timeout ? timeout.to_i : 60
  status = status.to_sym
  num = Integer(count)

  @result = BushSlicer::PersistentVolume.wait_for_labeled(*labels, count: num,
                       user: admin, seconds: timeout) do |pv, pv_hash|
    pv.status?(user: admin, status: status, cached: true)[:success]
  end

  cache_resources *@result[:matching]

  if !@result[:success] || @result[:matching].size != num
    logger.error("Wanted #{num} but only got '#{@result[:matching].size}' PVs labeled: #{labels.join(",")}")
    logger.info @result[:response]
    raise "See log, waiting for labeled PVs futile: #{labels.join(',')}"
  end
end

Given /^the#{OPT_QUOTED} PV status is #{SYM}$/ do |pv_name, status|
  @result = pv(pv_name).status?(status: status.to_sym, user: admin)

  unless @result[:success]
    raise "PV #{pv_name} does not have status: #{status}"
  end
end

Given /^the#{OPT_QUOTED} PV becomes terminating(?: within (\d+) seconds)?$/ do |pv_name, timeout|
  timeout = timeout ? timeout.to_i : 30
  success = wait_for(timeout) {
    pv(pv_name).deletion_timestamp(cached: false, quiet: true)
  }
  unless success
    raise "PV #{pv_name} did not become terminating within #{timeout}:\n#{pv.raw_resource.to_yaml}"
  end
end

# will create a PV with a random name and updating any requested path within
#   the object hash with the given value e.g.
# | ["spec"]["nfs"]["server"] | service("nfs-service").ip |
When /^admin creates a PV from "([^"]*)" where:$/ do |location, table|
  ensure_admin_tagged

  if location.include? '://'
    step %Q/I download a file from "#{location}"/
    pv_hash = YAML.load @result[:response], aliases: true, permitted_classes: [Symbol, Regexp]
  else
    pv_hash = YAML.safe_load_file location, aliases: true, permitted_classes: [Symbol, Regexp]
  end

  # use random name to avoid interference
  pv_hash["metadata"]["name"] = rand_str(5, :dns952)
  if pv_hash["kind"] != 'PersistentVolume'
    raise "why do you give me #{pv_hash["kind"]}"
  end

  table.raw.each do |path, value|
    # Expected targetPortal IPv6 address e.g. '[fd03::3066]:3260' value load as string instead YAML.load as a list
    if value.include?(']:')
      eval "pv_hash#{path} = value" unless path == ''
    else
      eval "pv_hash#{path} = YAML.load value" unless path == ''
    end
    # e.g. pv_hash["spec"]["nfs"]["server"] = 10.10.10.10
  end

  logger.info("Creating PV:\n#{pv_hash.to_yaml}")
  @result = BushSlicer::PersistentVolume.create(by: admin, spec: pv_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _pv = @result[:resource]
    _admin = admin
    teardown_add {
      @result = _pv.delete_graceful(by: _admin)
      unless @result[:success]
        raise "could not remove PV: #{_pv.name}"
      end
    }
  else
    logger.error(@result[:response])
    #raise "failed to create PV from: #{location}"
  end
end

Given /^I verify that the IAAS volume with id "(.+?)" was deleted(?: within #{NUMBER} seconds)?$/ do |vol_id, timeout|
  timeout = timeout ? Integer(timeout) : 30
  ensure_admin_tagged

  success = wait_for(timeout) do
    !env.iaas[:provider].get_volume_by_id(vol_id)
  end
  raise "volume with id #{vol_id} was not deleted!" unless success
end

Given /^I verify that the IAAS volume with id "(.+?)" has status "(.+?)"(?: within #{NUMBER} seconds)?$/ do |vol_id, status, timeout|
  timeout = timeout ? Integer(timeout) : 30
  ensure_admin_tagged

  actual_status = ""
  success = wait_for(timeout) do
    vol = env.iaas[:provider].get_volume_by_id(vol_id)
    if vol.nil?
      raise "the volume with id #{vol_id} does not exist!"
    else
      actual_status = env.iaas[:provider].get_volume_state(vol)
      actual_status == status
    end
  end
  raise "the volume with id #{vol_id} has not the status '#{status}' the current status is '#{actual_status}'." unless success
end

Given /^I verify that the IAAS volume for the "(.+?)" PV was deleted(?: within #{NUMBER} seconds)?$/ do |pv_name, timeout|
  timeout = timeout ? Integer(timeout) : 30
  ensure_admin_tagged

  success = wait_for(timeout) do
    !env.iaas[:provider].get_volume_by_openshift_metadata(pv_name, project.name)
  end
  raise "the IAAS volume bound to PV name #{pv_name} was not deleted!" unless success
end

Given /^I verify that the IAAS volume for the "(.+?)" PV becomes "(.+?)"(?: within #{NUMBER} seconds)?$/ do |pv_name, status, timeout|
  timeout = timeout ? Integer(timeout) : 30
  ensure_admin_tagged

  step %Q/I save volume id from PV named "#{pv_name}" in the clipboard/
  step %Q/the step should succeed/
  step %Q/I verify that the IAAS volume with id "#{cb.volume}" has status "#{status}" within #{timeout} seconds/
  step %Q/the step should succeed/
end
