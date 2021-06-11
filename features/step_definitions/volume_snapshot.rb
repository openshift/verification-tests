Given /^I check volume snapshot is deployed$/ do
  ensure_admin_tagged
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "default" project/
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=snapshot-controller |
    })
  step %Q/I switch to the default user/
end

# This step is to create VolumeSnapshotClass according to different parameter on differnt platforms, also it supports custom-defined parameter
When /^admin creates a VolumeSnapshotClass replacing paths:$/ do |table|
  ensure_admin_tagged

  path = "#{BushSlicer::HOME}/testdata/storage/snapshot"

  iaas_type = env.iaas[:type] rescue nil
  case iaas_type
  when "aws"
    file = "#{path}/volumesnapshotclass-aws.yaml"
  when "gce"
    file = "#{path}/volumesnapshotclass-gce.yaml"
  when "azure"
    file = "#{path}/volumesnapshotclass-azure.yaml"
  when "cinder"
    file = "#{path}/volumesnapshotclass-cinder.yaml"
  else
    raise "No volumesnapshot template for #{iaas_type} platform"
  end

  resource_hash = YAML.load_file file
  # replace paths from table
  table.raw.each do |path, value|
    eval "resource_hash#{path} = value"
  end
  logger.info("Creating VolumeSnapshotClass: \n#{resource_hash.to_yaml}")
  @result = BushSlicer::VolumeSnapshotClass.create(by: admin, spec: resource_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _vsc = @result[:resource]
    _admin = admin
    teardown_add { _vsc.ensure_deleted(user: _admin) }
  else
    logger.error(@result[:response])
    raise "Failed to create VolumeSnapshotClass."
  end
end


Given /^the#{OPT_QUOTED} volumesnapshot becomes ready(?: within (\d+) seconds)?$/ do |name, timeout|
  timeout ||= 60
  volume_snapshot(name).wait_till_ready(user: user, seconds: timeout)
end
