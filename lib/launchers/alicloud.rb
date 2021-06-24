require 'base64'
require 'cgi'
require 'json'
require 'openssl'
require 'time'
require 'thread'

lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'collections'
require 'common'
require 'cucuhttp'

module BushSlicer
  class Alicloud
    include Common::Helper
    include CollectionsIncl

    attr_reader :config

    def initialize(**opts)
      service_name = opts.delete(:service_name)
      if service_name
        @config = conf[:services, service_name]
      else
        @config = {}
      end

      config_opts = opts.delete(:config)
      if config_opts
        @config = deep_merge(@config, config_opts)
      end
    end

    # perform a request against Alibaba Cloud API
    # @see https://www.alibabacloud.com/help/doc-detail/25489.htm
    def request(api: "compute", action:, params: {}, noraise: false)
      api_url = config["#{api}_url".to_sym]
      # api_url = "https://ecs.cn-zhangjiakou.aliyuncs.com/"

      # method = "POST"
      method = "GET"
      process_params!(http: method, action: action, params: params)
      res = Http.request(method: method, url: api_url, params: params,
                         verify_ssl: OpenSSL::SSL::VERIFY_PEER,
                         open_timeout: 30)
      # Http.request(method: method, url: api_url, payload: params)
      # Http.request(method: method, url: api_url, payload: params.map{|k,v| "#{k}=#{CGI.escape(v)}"}.join("&"))

      unless noraise || res[:success]
        # Alicloud::RequestError only on issues related to the query
        # connection and server errors shold be distinguishable
        if res[:exitstatus].between?(400, 499)
          raise RequestError, res[:response]
        else
          raise res[:error]
        end
      end

      if res[:response].start_with? "{"
        res[:parsed] = JSON.load(res[:response])
      else
        res[:parsed] = {error: res[:response]}
      end
      return res
    end

    # generates the required common params for a request and adds them to params
    # @return undefined
    # @see https://www.alibabacloud.com/help/doc-detail/25490.htm
    private def process_params!(http:, action:, params:)
      params.merge!({
        "Action" => action,
        "AccessKeyId" => config[:auth][:key_id],
        "Format" => "JSON",
        "Version" => "2014-05-26",
        "Timestamp" => Time.now.utc.iso8601
      }) {|k, old, new| o} # do not override user supplied values
      sign!(http: http, action: action, params: params)
    end

    # generate request signature and adds to params
    # @return undefined
    # @see https://www.alibabacloud.com/help/doc-detail/25492.htm
    private def sign!(http:, action:, params:)
      params["SignatureMethod"] = "HMAC-SHA1"
      params["SignatureVersion"] = "1.0"
      params["SignatureNonce"] = random_hex(16)
      # params["SignatureNonce"] ||= SecureRandom.uuid.gsub("-", "")
      params.delete "Signature" # signature in params will always fail signing

      canonicalized_query_string = params.sort.map { |key, value|
        "#{key}=#{percent_encode value}"
      }.join("&")

      string_to_sign = %{#{http}&#{percent_encode("/")}&#{percent_encode(canonicalized_query_string)}}
      logger.debug("key to sign: #{string_to_sign}")

      params["Signature"] = hmac_sha1(string_to_sign)
      logger.debug("Signature: #{params["Signature"]}")
    end

    # @param data [String]
    # @return [String]
    private def hmac_sha1(data, secret: config[:auth][:key_secret])
      Base64.encode64(OpenSSL::HMAC.digest(
        'sha1',
        "#{secret}&",
        data
      )).strip
    end

    # @param length [Numeric] string length to return; only even values will
    #   produce correct result
    # @return [String] of non-secure random hex string of given length
    def random_hex(length)
      Random::DEFAULT.bytes(length/2).unpack('H*').first
    end

    # encode strings per Alibaba cloud rules for signing
    # @return [String] encoded string
    # @see https://www.alibabacloud.com/help/doc-detail/25492.htm
    private def percent_encode(str)
      str = str.to_s
      CGI.escape(str).gsub(?+, "%20").gsub(?*, "%2A").gsub("%7E", ?~)
    end

    # @param create_opts [Hash] VM launch options according to Alibaba docs
    # @param host_opts [Hash] additional machine access options, should be
    #   options valid for use in [BushSlicer::Host] constructor
    # @return [Array] of [Alicloud::Instance, BushSlicer::Host] pairs
    # @see https://www.alibabacloud.com/help/doc-detail/63440.htm
    def create_instance(create_opts: {}, host_opts: {}, generate_host: true)

      create_opts = self.create_opts.merge create_opts
      create_opts["ClientToken"] = random_hex(10)

      if create_opts["InstanceName"]
        # try to delete existing instances with the same name
        terminate_by_launch_opts(
          [{
            launch_opts: create_opts,
            name: create_opts["InstanceName"],
          }],
          wait: false
        )
      end

      res = request(action: "RunInstances", params: create_opts)

      logger.info "waiting for #{create_opts["Amount"] || 1} instances to " \
        "be created.."
      vms = res[:parsed]["InstanceIdSets"]["InstanceIdSet"].map do |id|
        Instance.new({
          "RegionId" => create_opts["RegionId"],
          "InstanceId" => id
        }, self)
      end

      if generate_host
        wait_for_instances_ip(360, *vms)

        return vms.map do |vm|
          host = get_vm_host(vm, host_opts)
          logger.info "created #{vm.name}: #{vm.public_ip}"
          [vm, host]
        end
      else
        return vms.map {|vm| [vm, nil]}
      end
    end
    alias create_instances create_instance

    # @return global instance create options
    def create_opts
      map_hash(config[:create_opts] || {}) {|k,v| [k.to_s, v]}.to_h
    end

    # @param vm [Alicloud::Instance]
    # @return [BushSlicer::Host]
    def get_vm_host(vm, host_opts = {})
      host_opts = (config[:host_opts] || {}).merge host_opts
      host_opts[:cloud_instance] = vm
      host_opts[:cloud_instance_name] = vm.name
      host_opts[:local_ip] = vm.private_ip
      return Host.from_ip(vm.public_ip, host_opts)
      # return Host.from_hostname(ip, host_opts)
    end

    # @param [Array<Hash>] launch_opts where each element is in the format
    #   `{name: "some-name", launch_opts: {...}}`;
    #   launch opts should match options for [#create_instance]
    # @return [Object] undefined
    def terminate_by_launch_opts(launch_opts, wait: true)
      list = launch_opts.map { |o| o[:launch_opts] }.uniq
      list.each do |opts|
        opts = create_opts.merge opts

        if [nil, 1].include?(opts["Amount"]) || !opts["UniqueSuffix"]
          to_delete = [opts["InstanceName"]]
        else
          to_delete = opts["Amount"].times.map { |i|
            "#{opts["InstanceName"]}#{sprintf("%03d", i+1)}"
          }
        end
        delete_by_name(opts["RegionId"], *to_delete, wait: wait)
      end
    end

    # wait for instances to match given criteria
    # @param timeout [Numeric] timeout seconds
    # @param instances [Array<Instance>]
    # @yield [Instance] should return true matching instances
    # @raise on timeout or other errors
    def wait_for_instances(timeout, *instances)
      raise unless block_given?
      success = wait_for(timeout, interval: 10) {
        res = request(
          action: "DescribeInstances",
          params: {
            "InstanceIds" => instances.map(&:id).to_json,
            "RegionId" => instances.first.region
          }
        )
        specs = res[:parsed]["Instances"]["Instance"]
        instances.each { |instance|
          spec_idx = specs.find_index {|s| s["InstanceId"] == instance.id}
          if spec_idx
            instance.update(specs[spec_idx])
            specs.delete_at(spec_idx)
          else
            instance.update({
              "InstanceId" => instance.id,
              "RegionId" => instance.region,
              "Status" => "Deleted",
            })
          end
        }
        instances.delete_if { |i| yield(i) }
        instances.empty?
      }

      unless success
        raise "timeout vaiting for instances to become '#{statuses}': " \
          "#{instances.map(&:id).to_json}"
      end
    end

    # @param timeout [Numeric] timeout seconds
    # @param statuses [String] instance status to wait for
    # @param instances [Array<Instance>]
    def wait_for_instances_status(timeout, statuses, *instances)
      statuses = [statuses].flatten
      wait_for_instances(timeout, *instances) { |i| statuses.include? i.status }
    end

    def wait_for_instances_ip(timeout, *instances)
      wait_for_instances(timeout, *instances) do |instance|
        instance.public_ip
      end
    end

    # @param region [String] region id
    # @param names [String] if you provide a single name, then you can use
    #   wildcards (Alibaba seems to accept shell like wildcard `*`)
    # @return [Array<Instance>]
    def get_by_name(region, *names)
      instances = []
      params = {
        "RegionId" => region,
        "PageSize" => 100,
      }

      if names.size == 1
        params["InstanceName"] = names.first
      end

      res = request(action: "DescribeInstances", params: params.dup)
      instances.concat res[:parsed]["Instances"]["Instance"].map { |instance|
        Instance.new instance, self
      }

      total_count = res[:parsed]["TotalCount"]
      if 100 < total_count
        ((total_count - 100)/100.0).ceil.times do |i|
          params["PageNumber"] = i + 2
          res = request(action: "DescribeInstances", params: params.dup)
          instances.concat res[:parsed]["Instances"]["Instance"].map { |ins|
            Instance.new ins, self
          }
        end
      end

      if names.size > 1
        instances.select! {|i| names.include? i.name}
      end

      return instances
    end

    # @param region [String] region id
    # @param names [String] see #get_by_name
    # @param wait [Boolean] should we wait for instance to be actually deleted
    # @return undefined
    def delete_by_name(region, *names, wait: false)
      if names.size == 0
        raise "please specify instance names to delete, could be with wildcard"
      end

      instances = get_by_name(region, *names)
      return if instances.size == 0
      logger.info "#{wait ? "deleting" : "best effort to delete"} " \
        "instances #{instances.map{|i| "#{i.name}/#{i.id}"}}"

      queue = Queue.new
      threads = []
      10.times { threads << Thread.new { while r = queue.pop; r.call; end } }
      stop_cache = []
      instances.each do |instance|
        delete_proc = proc {instance.delete!(wait: wait, graceful: true)}
        if instance.status.include?("Stop")
          queue.push(delete_proc)
        else
          stop_cache << delete_proc
          queue.push(
            proc {instance.stop!(force: true, wait: false, graceful: true)}
          )
        end
      end
      stop_cache.each { |p| queue.push p }
      10.times { queue.push nil } # stop the threads
      threads.each(&:value)
    end

    # @param ids [Array<String>] ids of tasks to list
    # @see https://www.alibabacloud.com/help/doc-detail/25622.htm
    def describe_tasks_by_id(region, *ids)
      params = {
        "RegionId" => region,
        "TaskIds" => ids.join(","),
        "PageSize" => 100
      }
      request(action: "DescribeTasks", params: params).
        dig(:parsed, "TaskSet", "Task")
    end

    # @param ids [Array<String>] ids of tasks to list
    def wait_tasks(timeout, region, *ids)
      success == wait_for(timeout, interval: 5) {
        tasks = describe_tasks_by_id(region, *ids)
        tasks.each { |task|
          ids.delete(task["TaskId"]) if task["TaskStatus"] == "Finished"
        }
        ids.empty?
      }

      unless success
        raise BushSlicer::TimeoutError, "Timeout waiting for tasks: #{ids}"
      end
    end

    private def regions
      unless @regions
        @regions =
          request(action: "DescribeRegions")[:parsed]["Regions"]["Region"]
      end
      @regions
    end

    # @return [Array] of the block eexcution results
    # @yield region_id, region_endpoint
    def for_each_region
      regions.map {|r| yield(r["RegionId"], r["RegionEndpoint"])}
    end

    # can be used to retry a call by given HTTP request string, e.g.
    #   POST /?AccessKeyId=LTAIs2WYGap0r3FL&Action=DescribeRegions&Format=JSON&RegionId=cn-qingdao&Signature=R8z6MU3MVZa%252Bn4%252BsX%252B9%252FBTIWBq0%253D&SignatureMethod=HMAC-SHA1&SignatureNonce=ffe3fed8b16a4f51b84f1ccc05cc690d&SignatureType=&SignatureVersion=1.0&Timestamp=2018-07-16T20%3A22%3A04Z&Version=2014-05-26
    #def test_req(params, api: "compute")
    #  if String === params
    #    method, _path = params.split(/\s/)
    #    query = _path.sub(/^\/\?(.*)$/, "\\1")
    #    raise if query == _path
    #    params = (CGI.parse(query).transform_values(&:first))
    #  end
    #  params.delete("Signature") # otherwise it will enter into the new calc
    #  request(api: api, params: params, action: params.delete("Action"))
    #end

    class AlibabaError < StandardError
    end

    class RequestError < AlibabaError
    end

    class ResourceNotFound < AlibabaError
    end

    class Instance
      include Common::BaseHelper

      attr_reader :connection, :id, :region

      # @param spec [Hash] provide at least "InstanceId" and "RegionId" keys
      def initialize(spec, connection)
        @connection = connection
        @id = spec["InstanceId"].freeze
        @region = spec["RegionId"].freeze
        update spec
      end

      def update(spec)
        if id == spec["InstanceId"] || region == spec["RegionId"]
          @spec = spec
        else
          raise "trying to update instance with wrong spec: #{id}/#{region}" \
            "vs #{spec["InstanceId"]}/#{spec["RegionId"]}"
        end
      end

      private def known_region?
        @spec&.dig()
      end

      # @see https://www.alibabacloud.com/help/doc-detail/25506.htm
      def spec(cached: true)
        unless cached && @spec
          res = connection.request(
            action: "DescribeInstances",
            params: {
              "InstanceIds" => [id].to_json,
              "RegionId" => region
            }
          )
          @spec = res[:parsed]["Instances"]["Instance"].first
          unless @spec
            raise ResourceNotFound, "no instnaces with id #{id} found"
          end
        end
        return @spec
      end

      def exists?
        status(cached: false) != "Deleted"
      end

      def status(cached: true)
        spec(cached: cached)["Status"]
      rescue ResourceNotFound
        "Deleted"
      end

      # @return [String]
      def public_ip(cached: true)
        public_ips(cached: cached)&.first
      end

      def public_ips(cached: true)
        spec(cached: cached).dig("PublicIpAddress", "IpAddress")
      end

      def private_ip(cached: true)
        private_ips(cached: cached)&.first
      end

      def private_ips(cached: true)
        if !spec(cached: cached).dig("InnerIpAddress", "IpAddress").empty?
          spec(cached: true).dig("InnerIpAddress", "IpAddress")
        else
          spec(cached: true).dig("VpcAttributes", "PrivateIpAddress", "IpAddress")
        end
      end

      def name(cached: true)
        spec(cached: cached)["InstanceName"]
      end

      # @param wait [Boolean, Numeric] seconds to wait for instance to stop
      # @param graceful [Boolean] when true method will not raise when instance
      #   is missing or is already stopped/stopping
      def stop!(graceful: true, force: false, wait: true)
        params = {
          "InstanceId" => id,
          "ForceStop" => !!force.to_s,
          "ConfirmStop" => !!force.to_s
        }
        res = connection.request(
          action: "StopInstance",
          params: params,
          noraise: graceful,
        )

        unless res[:success]
          # if we are here then graceful is true
          if res[:exitstatus] == 404 || res[:exitstatus] == 403 && res[:parsed]["Code"] == "IncorrectInstanceStatus"
            return nil
          else
            raise RequestError, "Failed to stop instance #{instance_id}: " \
              "#{res[:response]}"
          end
        end

        if wait
          timeout = Numeric === wait ? wait : 60
          success = wait_for(timeout, interval: 5) {
            status(cached: false) == "Stopped"
          }
          unless success
            raise BushSlicer::TimeoutError,
              "Timeout waiting for instance #{id} to stop. Status: #{status}"
          end
          return nil
        else
          return res[:parsed]["RequestId"]
        end
      end

      # @see #stop!
      # @see https://www.alibabacloud.com/help/doc-detail/25507.htm
      def delete!(graceful: true, wait: true)
        res = connection.request(
          action: "DeleteInstance",
          params: {"InstanceId" => id},
          noraise: graceful,
        )

        unless res[:success]
          # if we are here then graceful is true
          if res[:exitstatus] == 404
            return nil
          elsif res[:exitstatus] == 403 && res[:parsed]["Code"].include?("Status")
            stop!(force: true, graceful: true, wait: true)
            return delete!(graceful: false, wait: wait)
          else
            raise RequestError, "Failed to delete instance #{instance_id}: " \
              "#{res[:response]}"
          end
        end

        if wait
          timeout = Numeric === wait ? wait : 60
          success = wait_for(timeout, interval: 5) {
            status(cached: false) == "Deleted"
          }
          unless success
            raise BushSlicer::TimeoutError,
              "Timeout waiting to delete instance #{id}. Status: #{status}"
          end
          return nil
        else
          return res[:parsed]["RequestId"]
        end
      end
    end
  end
end

## Standalone test
if __FILE__ == $0
  extend BushSlicer::Common::Helper
  ali = BushSlicer::Alicloud.new(service_name: "alicloud")

  # params = {
  #   "RegionId" => "cn-zhangjiakou",
  #   "KeyPairName" => "keyname",
  #   "PublicKeyBody" => File.read(expand_private_path("path/key.pub"))
  # }
  # results = ali.for_each_region { |r|
  #   params["RegionId"] = r
  #   ali.request(action: "ImportKeyPair", params: params.dup, noraise: true)
  # }

  test_res = {}
  conf[:services].each do |name, service|
    if service[:cloud_type] == 'alibaba'
      ali = BushSlicer::Alicloud.new(service_name: name)
      res = true
      test_res[name] = res
      begin
        vm, host = ali.create_instance(
          create_opts: {"InstanceName" => "test_terminate"}
        ).flatten
        ali.wait_for_instances_status(360, ["Running"], vm)
        ( require 'pry'; binding.pry ) if ARGV.first == "true"
        ali.delete_by_name(service[:create_opts][:RegionId], "test_terminate*")
        test_res[name] = false
      rescue => e
        test_res[name] = e
      end
    end
  end

  test_res.each do |name, res|
    puts "Alibaba instance #{name} failed: #{res}"
  end

  require 'pry'; binding.pry
end
