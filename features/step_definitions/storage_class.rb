require 'yaml'

# will create a StorageClass with a random name and updating any requested path within
#   the object hash with the given value e.g.
# | ["metadata"]["name"] | sc-<%= project.name %> |
When /^admin creates a StorageClass( in the node's zone)? from #{QUOTED} where:$/ do |nodezone, location, table|
  ensure_admin_tagged

  if location.include? '://'
    step %Q/I download a file from "#{location}"/
    sc_hash = YAML.load @result[:response], aliases: true, permitted_classes: [Symbol, Regexp]
  else
    sc_hash = YAML.safe_load_file location, aliases: true, permitted_classes: [Symbol, Regexp]
  end

  # use random name to avoid interference
  sc_hash["metadata"]["name"] = rand_str(5, :dns952)
  if sc_hash["kind"] != 'StorageClass'
    raise "why do you give me #{sc_hash["kind"]}"
  end

  iaas_type = env.iaas[:type] rescue nil

  if nodezone && iaas_type == "gce" &&
      node.labels.has_key?("failure-domain.beta.kubernetes.io/zone")
    sc_hash["parameters"] ||= {}
    sc_hash["parameters"]["zone"] = node.labels["failure-domain.beta.kubernetes.io/zone"]
  end

  table.raw.each do |path, value|
    eval "sc_hash#{path} = value" unless path == ''
    # e.g. sc_hash["metadata"]["name"] = "sc_test_name"
  end

  logger.info("Creating StorageClass:\n#{sc_hash.to_yaml}")
  @result = BushSlicer::StorageClass.create(by: admin, spec: sc_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _sc = @result[:resource]
    _admin = admin
    teardown_add { _sc.ensure_deleted(user: _admin) }
  else
    logger.error(@result[:response])
    raise "failed to create StorageClass from: #{location}"
  end
end

Given(/^I have a StorageClass named "([^"]*)"$/) do | storageclass_name |
  step %Q/I run the :get admin command with:/, table(%{
    | resource      | StorageClass         |
    | resource_name | #{storageclass_name} |
  })

  step %Q/the step should succeed/
end

Given(/^I run commands on the StorageClass "([^"]*)" backing host:$/) do | storageclass_name, table|
  ensure_admin_tagged

  rest_url = storage_class(storageclass_name).rest_url(user: admin)
  hostname = URI.parse(rest_url).host

  opts = conf[:services, :storage_class_host]

  host = BushSlicer::SSHAccessibleHost.new(hostname, opts)

  @result = host.exec_admin(*table.raw.flatten)
end

Given(/^default storage class is patched to non-default$/) do
  ensure_admin_tagged
  ensure_destructive_tagged

  _sc = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash| sc.default? }.first
  if _sc
    logger.info "Default storage class will patched to non-default and be resotored after scenario:\n#{_sc.name}"
    cache_resources _sc
    _admin = admin
    patch_json_false = {"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}
    patch_json_true = {"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}
    patch_opts = {resource: "storageclass", resource_name: "#{_sc.name}"}
    @result = _admin.cli_exec(:patch, p: patch_json_false.to_json, **patch_opts)
    if @result[:success]
      teardown_add {
        @result = _admin.cli_exec(:patch, p: patch_json_true.to_json, **patch_opts)
        raise "Unable to restore default storage class #{_sc.name}!" unless @result[:success]
      }
    else
      raise "Unable to patch default storage class #{_sc.name} to non-default!"
    end
  end
end

Given(/^default storage class is deleted$/) do
  ensure_destructive_tagged
  if env.version_ge("3.3", user: user)
    _sc = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash|
      sc.default?
    }.first
    if _sc
      #Delete default storageclass
      logger.info "Default storage class will delete and be resotored after" \
       " scenario:\n#{_sc.name}"
      _sc.ensure_deleted
      # Restore storeclass after scenario
      _admin = admin
      teardown_add {
        raw = BushSlicer::Collections.deep_merge(
          _sc.raw_resource,
          { "metadata" => { "creationTimestamp" => nil } }
        )
        @result = BushSlicer::StorageClass.create(by: _admin, spec: raw)
        unless @result[:success]
          raise "Warning unable to restore default storage class #{_sc.name}!"
        end
      }
    else
      logger.info "There is no default storage class thus not deleting"
    end
  end
end

Given(/^admin clones storage class #{QUOTED} from #{QUOTED} with volume expansion (enabled|disabled)$/) do |target_sc, src_sc, expand|
  ensure_admin_tagged

  _expand = (expand == "enabled")
  step %Q/admin clones storage class "#{target_sc}" from "#{src_sc}" with:/, table(%{
    | ["allowVolumeExpansion"] | #{_expand} |
  })
end

Given(/^admin recreate storage class #{QUOTED} with:$/) do |sc_name, table|
  ensure_admin_tagged
  ensure_destructive_tagged

  step %Q/I run the :get admin command with:/, table(%{
    | resource      | StorageClass |
    | resource_name | #{sc_name}   |
    | o             | yaml         |
    | export        | true         |
  })
  sc_org = YAML.load @result[:stdout]

  sc_hash = YAML.load @result[:stdout]
  table.raw.each do |path, value|
    eval "sc_hash#{path} = value" unless path == ''
  end

  src_sc = storage_class(sc_name)
  src_sc.ensure_deleted(user: admin)

  logger.info("Creating StorageClass:\n#{sc_hash.to_yaml}")
  @result = BushSlicer::StorageClass.create(by: admin, spec: sc_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _sc = @result[:resource]
    _admin = admin
    teardown_add {
      _sc.ensure_deleted(user: _admin)
      BushSlicer::StorageClass.create(by: admin, spec: sc_org)
    }
  else
    logger.error(@result[:response])
    raise "failed to recreate StorageClass: #{sc_name}"
  end
end

Given(/^admin clones storage class #{QUOTED} from #{QUOTED} with:$/) do |target_sc, src_sc, table|
  ensure_admin_tagged

  # Use :default to comment out the different storage class names on AWS/GCE/OpenStack
  if "#{src_sc}" == ":default"
    _sc = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash| sc.default? }.first
    src_sc = _sc.raw_resource.dig("metadata", "name")
  end
  step %Q/I run the :get admin command with:/, table(%{
    | resource      | StorageClass |
    | resource_name | #{src_sc}    |
    | o             | yaml         |
  })
  sc_hash = YAML.load @result[:stdout]

  sc_hash["metadata"]["name"] = "#{target_sc}"
  # Generally, make cloned storage class as non-default storage class.
  if sc_hash.dig("metadata", "annotations", "storageclass.beta.kubernetes.io/is-default-class")
    sc_hash["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] = "false"
  end
  if sc_hash.dig("metadata", "annotations", "storageclass.kubernetes.io/is-default-class")
    sc_hash["metadata"]["annotations"]["storageclass.kubernetes.io/is-default-class"] = "false"
  end
  # Add/update any key/value pair.
  # Specially, add below line to make it a default storage class.
  # | ["metadata"]["annotations"]["storageclass.kubernetes.io/is-default-class"] | true |
  sc_hash["parameters"] ||= {}
  table.raw.each do |path, value|
    eval "sc_hash#{path} = YAML.load value" unless path == ''
  end
  # Make sure tag destructive when cloned storage class is default storage class.
  if sc_hash.dig("metadata", "annotations", "storageclass.kubernetes.io/is-default-class") == "true" ||
     sc_hash.dig("metadata", "annotations", "storageclass.beta.kubernetes.io/is-default-class") == "true"
    ensure_destructive_tagged
  end
  logger.info("Creating StorageClass:\n#{sc_hash.to_yaml}")
  @result = BushSlicer::StorageClass.create(by: admin, spec: sc_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _sc = @result[:resource]
    _admin = admin
    teardown_add { _sc.ensure_deleted(user: _admin) }
  else
    logger.error(@result[:response])
    raise "failed to clone StorageClass from: #{src_sc}"
  end
end

Given /^default storageclass is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  ensure_admin_tagged
  cb_name = 'default_sc' unless cb_name
  _sc = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash| sc.default? }.first
  raise "Unable to get default storage class " unless _sc
  cb[cb_name] = _sc
  cache_resources _sc
end

When /^admin creates new in-tree storageclass with:$/ do |table|
  ensure_admin_tagged
  project_name = project.name

  platform = infrastructure('cluster').platform.downcase
  case platform
  when 'aws'
    provisioner = 'aws-ebs'
  when 'gcp'
    provisioner = 'gce-pd'
  when 'azure'
    provisioner = 'azure-disk'
  when 'vsphere'
    provisioner = 'vsphere-volume'
  when 'openstack'
    provisioner = 'cinder'
  else
    logger.warn "Unsupported platform `#{platform}`"
    skip_this_scenario
  end

  # load file
  file = "#{BushSlicer::HOME}/testdata/storage/misc/in-tree-storageClass-template.yaml"
  sc_hash = YAML.safe_load_file file, aliases: true, permitted_classes: [Symbol, Regexp]

  # replace paths from table
  sc_hash["parameters"] ||= {}
  table.raw.each do |path, value|
      eval "sc_hash#{path} = YAML.load value" unless path == ''
  end

  # After CSI Migration the default volumeType change to 'gp3', but most aws local zones nodes don't support gp3 type volume
  if platform == "aws"
    sc_hash["parameters"]["type"] = "gp2"
  end

  # if no volumeBindingMode exists in tc, we need to pass vSphere=Immediate, others=WaitForFirstConsumer
  if !sc_hash.dig("volumeBindingMode")
    if platform == "vsphere"
      sc_hash["volumeBindingMode"] = "Immediate"
    else
      sc_hash["volumeBindingMode"] = "WaitForFirstConsumer"
    end
  end

  # replace the provisioner value according to platform wise
  sc_hash["provisioner"] = "kubernetes.io/#{provisioner}"

  logger.info("Creating StorageClass:\n#{sc_hash.to_yaml}")
  @result = BushSlicer::StorageClass.create(by: admin, spec: sc_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _sc = @result[:resource]
    _admin = admin
    teardown_add { _sc.ensure_deleted(user: _admin) }
  else
    logger.error(@result[:response])
    raise "failed to clone StorageClass from: #{src_sc}"
  end
end

Given(/^default storage class exists$/) do
  ensure_admin_tagged
  _sc = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash| sc.default? }.first
  if _sc
    logger.info "Default storage class: #{_sc.name} exists"
  else
    logger.warn "No default storageclass exist, skip for this scenario"
    skip_this_scenario
  end
end
