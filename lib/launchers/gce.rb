require 'google/apis/compute_v1'
require 'googleauth'
# require 'signet/oauth_2/client'

lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'collections'
require 'common'

module BushSlicer
  class GCE
    include Common::Helper
    include CollectionsIncl
    attr_reader :config

    Compute = Google::Apis::ComputeV1 # Alias the module

    def initialize(**opts)
      @config = conf[:services, opts.delete(:service_name) || :GCE].merge opts
    end

    # if we care about a specific project, we could in the future use:
    #   https://cloud.google.com/compute/docs/reference/beta/zones/list
    # but it should be a instance method and require a network call
    def self.regions
      {
        "asia-east1": [?a, ?b, ?c].map {|z| "asia-east1-#{z}"},
        "asia-northeast1": [?a, ?b, ?c].map {|z| "asia-northeast1-#{z}"},
        "asia-southeast1": [?a, ?b].map {|z| "asia-southeast1-#{z}"},
        "australia-southeast1": [?a, ?b, ?c].map {|z| "australia-southeast1-#{z}"},
        "europe-west1": [?b, ?c, ?d].map {|z| "europe-west1-#{z}"},
        "europe-west2": [?a, ?b, ?c].map {|z| "europe-west2-#{z}"},
        "us-central1": [?a, ?b, ?c, ?f].map {|z| "us-central1-#{z}"},
        "us-east1": [?b, ?c, ?d].map {|z| "us-east1-#{z}"},
        "us-east4": [?a, ?b, ?c].map {|z| "us-east4-#{z}"},
        "us-west1": [?a, ?b, ?c].map {|z| "us-west1-#{z}"}
      }
    end

    def compute
      return @compute if @compute

      @compute = Compute::ComputeService.new
      @compute.client_options.application_name = "BushSlicer"
      @compute.client_options.application_version = GIT_HASH
      # @compute.client_options.proxy_url = ENV['http_proxy'] if ENV['http_proxy']

      if config[:json_cred] && (config[:auth_type].nil? || config[:auth_type] == "json")
        begin
          json_cred_abs_path = expand_private_path(config[:json_cred])
        rescue
          logger.error "Possible issue OCPQE-240, tempfile: #{config[:avoid_garbage_collection]&.inspect}"
          raise
        end
        File.open(json_cred_abs_path, "r") do |json_io|
          @compute.authorization = Google::Auth::DefaultCredentials.make_creds(
              scope: config[:scopes],
              json_key_io: json_io
          )
        end
      elsif config[:signet_opts] && (config[:auth_type].nil? || config[:auth_type] == "signet")
        aopts = config[:signet_opts].dup
        aopts[:signing_key] = OpenSSL::PKey::RSA.new(aopts[:signing_key])
        @compute.authorization = Signet::OAuth2::Client.new(**aopts)
      elsif config[:token_json] && (config[:auth_type].nil? || config[:auth_type] == "token")
        token_hash = Signet::OAuth2.parse_credentials(config[:token_json], "application/json")
        @compute.authorization = Signet::OAuth2::Client.new(token_hash)
      else
        # try to use default auth from environment see:
        # https://github.com/google/google-auth-library-ruby
        auth = Google::Auth.get_application_default(config[:scopes])
        @compute.authorization = auth
      end
      @compute.authorization.fetch_access_token! unless @compute.authorization.access_token
      return @compute
    end

    # image_name is RE2 syntax see:
    #   https://github.com/google/re2/blob/master/doc/syntax.txt
    # @return [Google::Apis::ComputeV1::Image] single image,
    #   where multiple matches return latest match or nil if not found
    def image_by_name(image_name, project = config[:project])
      images = compute.list_images(project, filter: "name eq #{image_name}")
      if images.items
        # TODO: check image status
        return (images.items.sort_by {|i| i.creation_timestamp}).last
      else
        raise "Cannot find the image: #{image_name}"
      end
    end

    # image_name is RE2 syntax see:
    #   https://github.com/google/re2/blob/master/doc/syntax.txt
    # @return [Google::Apis::ComputeV1::Snapshot] single snapshot,
    #   where multiple matches return latest match or nil if not found
    def snapshot_by_name(snapshot_name, project = config[:project])
      snapshots = compute.list_snapshots(project, filter: "name eq #{snapshot_name}")
      if snapshots.items
        # TODO: check status
        return (snapshots.items.sort_by {|s| s.creation_timestamp}).last
      else
        raise "Can not find the snapshot: #{snapshot_name}"
      end
    end

    def get_volume_by_openshift_metadata(pv_name, project_name)
      disk_id_regex = ".*\"kubernetes.io/created-for/pv/name\":\"#{pv_name}\".*\"kubernetes.io/created-for/pvc/namespace\":\"#{project_name}\".*"
      ld = compute.list_disks(@config[:project], @config[:zone], filter: "description eq #{disk_id_regex}").items
      if ld
        return ld.first
      else
        return nil
      end
    end

    def get_volume_by_id(id)
      # the gem will raise if we request resource which does not exist. We dont want that.
      # I it will raise with a "notFound" error we return nil. In case of diff. error we raise as normaly.
      begin
        return compute.get_disk(@config[:project], @config[:zone], id)
      rescue Google::Apis::ClientError => e
        raise e.message unless e.message.include?("was not found") && e.status_code == 404
        return nil
      end
    end

    def get_volume_state(disk)
      if disk
       return disk.status
      else
        raise "Volume does not exist!"
      end
    end

    # @input region_name
    # @input status: filter to be used when calling the list_instances method, default to RUNNING
    # @return <Array> of instance, if
    def get_instances_by_status(zone: nil, status: 'RUNNING')
      compute.list_instances(@config[:project], zone, filter: "status eq '#{status.upcase}'").items
    end

    # @return Hash of zones keyed by region name
    def regions
      r = {}
      res = compute.list_regions(@config[:project])
      res.items.each { |i| r[i.name] = i.zones.map {|z| z.split('/')[-1]} }
      return r
    end

    # @return <Float>
    def instance_uptime(inst)
      return (Time.now - Time.parse(inst.creation_timestamp)) / (60*60).round(2)
    end


    # @param names [String, Array<String>] one or more names to launch
    # @param project [String] project name we work with
    # @param zone [String] zone name we work with
    # @param user_data [String] convenience to add metadata `startup-script` key
    # @param instance_opts [Hash] additional machines launch options
    # @param host_opts [Hash] additional machine access options, should be
    #   options valid for use in [BushSlicer::Host] constructor
    # @param boot_disk_opts [Hash] convenience way to merge some options for
    #   the boot disk without need to replace the whole disks configuration;
    #   disks from global config will be searched for the boot option and that
    #   disk entry will be intelligently merged
    # @return [Array] of [Instance, BushSlicer::Host] pairs
    def create_instance( names,
                         project: config[:project],
                         zone: config[:zone],
                         user_data: nil,
                         instance_opts: {},
                         boot_disk_opts: {},
                         host_opts: {})

      names = [ names ].flatten.map {|n| normalize_instance_name(n)}
      instance_opts = process_instance_opts( project: project,
                                             zone: zone,
                                             user_data: user_data,
                                             instance_opts: instance_opts,
                                             boot_disk_opts: boot_disk_opts)

      ## best effort delete any existing instances with same name
      del = names.map do |name|
        compute.delete_instance(project, zone, name) rescue nil
      end
      del.each_with_index do |op, index|
        if op
          logger.warn "deleting stale instance #{names[index]}"
          wait_status(op, "DONE", timeout: 240)
        end
      end

      ## create the instances
      create = names.map do |name|
        logger.debug "calling insert instance #{name}"
        instance_opts[:name] = name
        instance_object = Google::Apis::ComputeV1::Instance.new(instance_opts)
        compute.insert_instance(project, zone, instance_object)
      end
      return create.map.with_index do |create_op, index|
        logger.info "waiting for instance #{names[index]}"
        op_report_str = "create #{names[index]} op"
        res = operation_from_hash(wait_status(create_op, "DONE",
                                              timeout: 360,
                                              obj_report_name: op_report_str))
        if res.error
          res.error.errors.each do |e|
            logger.error e.message
          end
          raise("error launching instance #{names[index]} with " <<
                "HTTP status #{res.http_error_status_code}, see log")
        else
          if res.warnings
            res.warnings.each do |w|
              logger.warn w.message
              # todo: print also w.data
            end
          end
          ihash = wait_status(res.target_link, "RUNNING", timeout: 600)
          return_val = get_instance_host(ihash, host_opts)
          logger.info "started #{return_val[0].name}: #{return_val[1].hostname}"
          return_val
        end
      end
    end

    alias create_instances create_instance

    # @see #create_instance
    private def process_instance_opts( project: config[:project],
                                       zone: config[:zone],
                                       user_data: nil,
                                       instance_opts: {},
                                       boot_disk_opts: {} )

      override_opts = instance_opts
      global_opts = config[:instance_opts]

      # avoid conflicts with machine_type (do before generic opts merger)
      machine_type_keys = [ :machine_type_name, :machine_type ]
      unless (override_opts.keys & machine_type_keys).empty?
        global_opts = global_opts.reject {|k,v| machine_type_keys.include? k}
      end

      # generic opts merge
      instance_opts = deep_merge global_opts, instance_opts

      # override boot disk options before options normalization
      if boot_disk_opts && !boot_disk_opts.empty?
        instance_opts[:disks] = merge_boot_disk_opts instance_opts[:disks],
                                                     boot_disk_opts
      end

      # normalize convenience options, like update some names to urls
      instance_opts = normalize_instance_opts(project, zone, instance_opts)

      # handle user data made easy
      if user_data && !user_data.empty?
        instance_opts[:metadata] ||= {}
        instance_opts[:metadata][:items] ||= []
        instance_opts[:metadata][:items] <<
                      {key: "user-data", value: user_data}
      end

      return instance_opts
    end

    private def normalize_instance_opts(project, zone, instance_opts)
      normalized = {}
      instance_opts.each do |key, value|
        case key
        when :machine_type_name
          if !instance_opts.has_key?(:machine_type)
            normalized[:machine_type] = compute.get_machine_type(
              project, zone, value).self_link
          end
        when :disks
          normalized[:disks] = normalize_disks(project, zone, value)
        when :metadata
          normalized[:metadata] = normalize_metadata(project, zone, value)
        else
          normalized[key] = value
        end
      end
      return normalized
    end

    private def normalize_disks(project, zone, disks)
      res = []
      disks.each do |disk|
        normalized = deep_hash_symkeys(disk)
        if normalized.has_key? :initialize_params
          params = {}
          normalized[:initialize_params].each do |key, value|
            case key
            when :image_name
              # TODO: support image name from any project
              params[:source_image] = image_by_name(value, project).self_link
            when :snapshot_name
              # TODO: support snapshot name from any project
              params[:source_snapshot] =
                snapshot_by_name(value, project).self_link
            when :img_snap_name
              # try to guess what poor user desires
              if value.include? '/'
                # this is an url
                if value.include? "images/"
                  params[:source_image] = value
                elsif value.include? "snapshots/"
                  params[:source_snapshot] = value
                else
                  raise "#{value} a URL but wrong or " <<
                                 "I don't know how to create a disk from"
                end
              else
                # we need to get actual URL from current project
                # check if image with that name exists else try snapshot
                begin
                  params[:source_image] = image_by_name(value, project).self_link
                rescue
                  params[:source_snapshot] =
                    snapshot_by_name(value, project).self_link
                end
              end
            else
              params[key] = value
            end
          end
          normalized[:initialize_params] = params
        end
        res << normalized
      end
      return res
    end

    private def normalize_metadata(project, zone, metadata)
      return metadata unless metadata[:items]
      res = metadata.dup
      res[:items] = items = []
      metadata[:items].each do |item|
        item = hash_symkeys item
        if item.has_key? :from_file
          key = item[:key]
          value = File.read(expand_private_path(
            item[:from_file],
            public_safe: !(key =~ /ssh/i)
          ))
          items << {key: key, value: value}
        else
          items << item
        end
      end
      return res
    end

    # require that existing boot disk options are present
    private def merge_boot_disk_opts(orig_opts, override_opts)
      if override_opts.has_key?(:boot) && !override_opts[:boot]
        raise "should not remove boot disk"
      end
      if override_opts.has_key?(:source) &&
                     override_opts.has_key?(:initialize_params)
        raise "cannot have both :source and :initialize_params"
      end
      return orig_opts.map do |disk|
        if disk[:boot] || disk["boot"]
          # this is the boot disk so we merge here; symkeying done in normalize
          #   method so we might still have non-symbol keys
          boot_disk = deep_hash_symkeys(disk)
          boot_disk = boot_disk.merge(override_opts) { |key, oldval, newval|
            if key == :initialize_params
              # special handling of :initialize_params merging
              # that means leave only image specifiers in new config
              img_specs = [:snapshot_name, :image_name,
                           :source_snapshot, :source_image,
                           :img_snap_name]
              if !(newval.keys & img_specs).empty?
                oldval = oldval.select { |k,v| !img_specs.include?(k) }
              end
              deep_merge oldval, newval
            elsif Hash === oldval && Hash === newval
              # normal merging
              deep_merge oldval, newval
            else
              newval
            end
          }
          if override_opts[:initialize_params]
            boot_disk.delete(:source)
          elsif override_opts[:source]
            boot_disk.delete(:initialize_params)
          end
          boot_disk # this is return value
        else
          # non-boot disk, we pass through
          disk
        end
      end
    end

    # names need to be DNS compatible up to 63 characters
    private def normalize_instance_name(name)
      name.gsub("_","-")
    end

    def get_instance_external_ip(project, zone, instance_name)
      instance_external_ip compute.get_instance(project, zone, instance_name)
    end

    # @param instance [Google::Apis::ComputeV1::Operation.new]
    def instance_external_ip(instance)
      interfaces = instance.network_interfaces
      interfaces.each do |i|
        return i.access_configs[0].nat_ip rescue nil
      end
      raise "no external IP found for #{instance.name}"
    end

    # get API object selfLink intil status becomes as requested
    # @param object [#self_link, String] if string, we use it as the desired URL
    # @param obj_report_name [String] optionally the human readable name of
    #   object to make error message easier to understand
    def wait_status(object, status, timeout: 120, interval: 10,
                    obj_report_name: nil)
      url = object.respond_to?(:self_link) ? object.self_link : object
      return if object.respond_to?(:status) && object.status == status
      last_status = nil
      ohash = nil
      success = wait_for(timeout, interval: interval) {
        ohash = JSON.load(compute.http(:get, url))
        last_status = ohash["status"]
        last_status == status
      }

      if success
        return ohash
      else
        raise "#{obj_report_name || url} never reached #{status.inspect}, only #{last_status.inspect}"
      end
    end

    # @param instance_spec [Instance, Hash] instance object or hash
    #   representation
    # @return [Array] with two elements - Instance and BushSlicer::Host
    def get_instance_host(instance_spec, host_opts = {})
      host_opts = config[:host_opts].merge host_opts
      instance = instance_spec.kind_of?(Hash) ?
                 instance_from_hash(instance_spec) : instance_spec
      host_opts[:cloud_instance] = instance
      host_opts[:cloud_instance_name] = instance.name
      ip = instance_external_ip instance
      # Sometimes could not use hostname obtained by reverse DNS lookup
      # I assume because hostname starts with digits, play safe and use IPs
      # until issue is better understood.
      # return [instance, Host.from_ip(ip, host_opts)]
      return [instance, Host.from_hostname(ip, host_opts)]
    end

    # @param [Array<Hash>] launch_opts where each element is in the format
    #   `{name: "some-name", launch_opts: {...}}`; launch opts should match options for
    #   [#create_instance]
    # @return [Object] undefined
    def terminate_by_launch_opts(launch_opts)
      del = []
      launch_opts.each do |instance_opts|
        name = instance_opts[:name]
        zone = instance_opts.dig(:launch_opts, :zone) || config[:zone]
        project = instance_opts.dig(:launch_opts, :project) || config[:project]

        logger.info "Trying to terminate GCE instance: #{name}"
        begin
          del << compute.delete_instance(project, zone, name)
        rescue Google::Apis::ClientError => e
          if e.message.include? "notFound"
            del << nil
          else
            raise
          end
        end
      end
      del.each_with_index do |op, index|
        if op
          logger.info "waiting delete operation for #{launch_opts[index][:name]}"
          wait_status(op, "DONE", timeout: 240)
        end
      end
    end

    # @param cls [Class] target class to instantiate
    # @param json [String] json body
    # @return [Object] instance of the cls class
    # @note https://github.com/google/google-api-ruby-client/issues/363
    private def from_json(cls, json)
      representer = cls.const_get(:Representation)
      fail "Invalid type specified" if representer.nil?
      representer.new(cls.new).from_json(json, unwrap: cls)
    end

    private def operation_from_hash(hash)
      # the crazy google API pulls in Active support
      # https://github.com/google/google-api-ruby-client/issues/364 - remove Active support
      #hash = deep_map_hash(hash) do |k, v|
      #  [ k.underscore.to_sym, v ]
      #end
      #Google::Apis::ComputeV1::Operation.new **hash
      from_json(Google::Apis::ComputeV1::Operation, hash.to_json)
    end

    # @return [Google::Apis::ComputeV1::Instance]
    private def instance_from_hash(instance_hash)
      from_json(Google::Apis::ComputeV1::Instance, instance_hash.to_json)
    end
  end
end
