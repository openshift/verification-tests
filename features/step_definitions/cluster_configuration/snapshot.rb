Given /^volume snapshot controller and provisioner is deployed$/ do
  ensure_admin_tagged
  ensure_destructive_tagged

  path = "<%= ENV['BUSHSLICER_HOME'] %>/testdata/storage/snapshot"
  gce_files = [
    "#{path}/deployment-gce.yaml"
  ]
  aws_files = [
    "#{path}/deployment-aws.yaml"
  ]
  snapshot_files = [
    "#{path}/ServiceAccount-controller.yaml",
    "#{path}/ClusterRole-controller.yaml",
    "#{path}/ClusterRoleBinding-controller.yaml",
    "#{path}/ClusterRole-admin.yaml",
    "#{path}/ClusterRoleBinding-admin.yaml",
    "#{path}/storageclass.yaml"
  ]
  all_files = []

  iaas_type = env.iaas[:type] rescue nil
  case iaas_type
  when "gce"
    all_files = (gce_files + snapshot_files)
  when "aws"
    step %Q{I download a file from "#{path}/secret-aws.yaml"}
    resource = YAML.load(@result[:response])
    filepath = @result[:abs_path]

    resource["data"]["access-key-id"] = env.iaas.access_key
    resource["data"]["secret-access-key"] = env.iaas.secret_key

    File.write(filepath, resource.to_yaml)
    result = admin.cli_exec(:create, f: filepath)
    raise "error creating from #{path}/secret-aws.yaml" unless result[:success]

    all_files = (aws_files + snapshot_files)
  else
    raise "snapshot not supported on #{iaas_type}"
  end

  status_marker = '#####'
  all_files.each { |file|
    res = admin.cli_exec(:create, f: file)
    unless res[:success]
      logger.warn("error creating from file #{file}")
      status_marker = "#{file}"
      break
    end
  }

  if status_marker != '#####'
    all_files.each { |file|
      res = admin.cli_exec(:delete, f: file)
      logger.info("deleting from file #{file}")
    }
    raise "error creating from file #{status_marker}"
  end
end
