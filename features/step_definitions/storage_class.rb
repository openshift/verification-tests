require 'yaml'

# will create a StorageClass with a random name and updating any requested path within
#   the object hash with the given value e.g.
# | ["metadata"]["name"] | sc-<%= project.name %> |
When /^admin creates a StorageClass( in the node's zone)? from #{QUOTED} where:$/ do |nodezone, location, table|
  ensure_admin_tagged

  if location.include? '://'
    step %Q/I download a file from "#{location}"/
    sc_hash = YAML.load @result[:response]
  else
    sc_hash = YAML.load_file location
  end

  # use random name to avoid interference
  sc_hash["metadata"]["name"] = rand_str(5, :dns952)
  if sc_hash["kind"] != 'StorageClass'
    raise "why do you give me #{sc_hash["kind"]}"
  end

  # starts from 3.6, change apiVersion from v1beta1 to v1
  if env.version_cmp("3.6", user: user) >= 0
    sc_hash["apiVersion"] = "storage.k8s.io/v1"
  else
    sc_hash["apiVersion"] = "storage.k8s.io/v1beta1"
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
  @result = VerificationTests::StorageClass.create(by: admin, spec: sc_hash)

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

  host = VerificationTests::SSHAccessibleHost.new(hostname, opts)

  @result = host.exec_admin(*table.raw.flatten)
end

Given(/^default storage class is deleted$/) do
  ensure_destructive_tagged
  if env.version_ge("3.3", user: user)
    _sc = VerificationTests::StorageClass.get_matching(user: user) { |sc, sc_hash|
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
        raw = VerificationTests::Collections.deep_merge(
          _sc.raw_resource,
          { "metadata" => { "creationTimestamp" => nil } }
        )
        @result = VerificationTests::StorageClass.create(by: _admin, spec: raw)
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
  @result = VerificationTests::StorageClass.create(by: admin, spec: sc_hash)

  if @result[:success]
    cache_resources *@result[:resource]

    # register mandatory clean-up
    _sc = @result[:resource]
    _admin = admin
    teardown_add {
      _sc.ensure_deleted(user: _admin)
      VerificationTests::StorageClass.create(by: admin, spec: sc_org)
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
    _sc = VerificationTests::StorageClass.get_matching(user: user) { |sc, sc_hash| sc.default? }.first
    src_sc = _sc.raw_resource.dig("metadata", "name")
  end
  step %Q/I run the :get admin command with:/, table(%{
    | resource      | StorageClass |
    | resource_name | #{src_sc}    |
    | o             | yaml         |
    | export        | true         |
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
  # | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | true |
  table.raw.each do |path, value|
    eval "sc_hash#{path} = YAML.load value" unless path == ''
  end
  # Make sure tag destructive when cloned storage class is default storage class.
  if sc_hash.dig("metadata", "annotations", "storageclass.kubernetes.io/is-default-class") == "true" ||
     sc_hash.dig("metadata", "annotations", "storageclass.beta.kubernetes.io/is-default-class") == "true"
    ensure_destructive_tagged
  end

  logger.info("Creating StorageClass:\n#{sc_hash.to_yaml}")
  @result = VerificationTests::StorageClass.create(by: admin, spec: sc_hash)

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
