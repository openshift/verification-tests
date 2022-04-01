require 'openshift/cluster_resource'
require 'openshift/node_taint'

module BushSlicer
  # @note this class represents OpenShift environment Node API pbject and this
  #   is different from a BushSlicer::Host. Underlying a Node, there always is a
  #   Host but not all Hosts are Nodes. Not sure if we can always have a
  #   mapping between Nodes and Hosts. Depends on access we have to the env
  #   under testing and proper configuration.
  class Node < ClusterResource
    RESOURCE = "nodes"

    def update_from_api_object(node_hash)
      super

      h = node_hash["metadata"]
      props[:uid] = h["uid"]
      props[:labels] = h["labels"]
      props[:spec] = node_hash["spec"]
      props[:status] = node_hash["status"]
      return self
    end

    # @return [BushSlicer:Host] underlying this node
    # @note may raise depending on proper OPENSHIFT_ENV_<NAME>_HOSTS
    # @note will return acorrding to:
    # 1. if the node name matches hosts, then use host
    # 2. if  any env pre-defined hosts woned node name ip, then use it.
    def host
      return @host if @host

      # try to figure this out from host specification
      potential = env.hosts.select { |h| h.hostname.start_with? self.name }
      # set internal IP and DNS name when possible to avoid pointless SSH


      if potential.size == 1
        @host = potential.first
        @host[:node] = self
        return @host
      end

      hostname = labels["kubernetes.io/hostname"] || name

      # check whether we detect node hostname as local to any hosts
      # here we need to be more careful because we may not have access to
      #   all environment hosts, e.g. elastic load balancer hosts
      @host = env.node_hosts.find do |h|
        env.nodes.none? {|n| n.host_var == h} && h.local_ip?(hostname)
      end
      if @host
        @host[:node] = self
        return @host
      end

      # treat as a new host
      # set it to use bastion as usually we only see internal IP
      roles = is_master? ? [:master, :node] : [:node]
      unless env.bastion_hosts.empty?
        flags = "/b/"
      end
      @host = env.host_add(hostname, node: self, roles: roles, flags: flags)
      return @host if @host

      raise("no host mapping for #{self.name}")
    end

    # used as helper when optimizing host lookup
    protected def host_var
      @host
    end

    def taints(user: nil, cached: true, quiet: true)
      param = get_cached_prop(prop: :spec, user: user, cached: cached, quiet: quiet)
      return param["taints"]&.map {|t| NodeTaint.new(self, t)} || []
    end

    def service
      @service ||= BushSlicer::Platform::NodeService.discover(host, env)
    end

    def schedulable?(user: nil, cached: true, quiet: false)
      spec = get_cached_prop(prop: :spec, user: user, cached: cached, quiet: quiet)
      return !spec['unschedulable']
    end

    def is_worker?(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      res = rr.dig('metadata', 'labels', 'node-role.kubernetes.io/worker')
      return ! res.nil?
    end

    def is_master?(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      res = rr.dig('metadata', 'labels', 'node-role.kubernetes.io/master')
      return ! res.nil?
    end
  
    def is_windows_worker?(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'labels', 'kubernetes.io/os') == "windows"
    end    

    def ready?(user: nil, cached: false, quiet: false)
      status = get_cached_prop(prop: :status, user: user, cached: cached, quiet: quiet)
      result = {}
      result[:success] = status['conditions'].any? do |con|
        con['type'] == "Ready" && con['status'] == "True"
      end
      return result
    end
    def address(user: nil, type:, cached: true, quiet: false)
      addresses = raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'addresses')
      c = addresses.find { |c|
        c.dig('type') == type
      } or raise "No address with type #{type} found."
      return c.dig('address')
    end


    # @return [Integer} capacity cpu in 'm'
    def capacity_cpu(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      cpu = obj.dig("status", "capacity", "cpu")
      return unless cpu
      parsed = cpu.match(/\A(\d+)([a-zA-Z]*)\z/)
      number = Integer(parsed[1])
      unit = parsed[2]
      case unit
      when ""
        return number * 1000
      when "m"
        return number
      else
        raise "unknown cpu unit '#{unit}'"
      end
    end

    def capacity_pods(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      return obj.dig("status", "capacity", "pods")&.to_i
    end

    # @return [Integer] memory in bytes
    def capacity_memory(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      mem = obj.dig("status", "capacity", "memory")
      return unless mem
      return convert_to_bytes(mem)
    end

    # @return [Integer} capacity cpu in 'm'
    def allocatable_cpu(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      cpu = obj.dig("status", "allocatable", "cpu")
      return unless cpu
      return convert_cpu(cpu)
    end

    def allocatable_pods(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      return obj.dig("status", "allocatable", "pods")&.to_i
    end

    # now only write for x86_64 arch
    def allocatable_hugepages(user: nil, cached: true, quiet: false, size: "2Mi")
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      hp = obj.dig("status", "allocatable", "hugepages-"+size)
      return hp ? convert_to_bytes(hp) : 0
    end

    def hugepages_supported?(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      return obj.dig("status", "allocatable")&.keys&.any? {|k| k.start_with? "hugepages-"}
    end

    # @return [Integer] memory in bytes
    def allocatable_memory(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      mem = obj.dig("status", "allocatable", "memory")
      return unless mem
      return convert_to_bytes(mem)
    end

    def external_id(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'externalID')
    end

    def region(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('metadata', 'labels', 'failure-domain.beta.kubernetes.io/region')
    end

    def zone(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('metadata', 'labels', 'failure-domain.beta.kubernetes.io/zone')
    end

    def pods(user: nil, cached: true, quiet: false)
      unless cached && props[:pods]
        get_opts = {
          resource: "pods",
          all_namespaces: true,
          fieldSelector: "spec.nodeName=#{self.name},status.phase!=Failed,status.phase!=Succeeded",
          output: "yaml"
        }
        get_opts[:_quiet] = true if quiet
        res = default_user(user).cli_exec(:get, **get_opts)

        if res[:success]
          res[:parsed] = YAML.load(res[:response])
        else
          raise "cannot list pods in all namespaces"
        end

        # need record pods list for sched_number_total calculation
        props[:pods] = res[:parsed]["items"].map { |p|
          Pod.from_api_object(
            Project.new(
              name: p["metadata"]["namespace"],
              env:env
            ),
            p
          )
        }
      end
      return props[:pods]
    end

    # return value like {:cpu=>420, :memory=>2132803584}
    def requests_total(user: nil, cached: true, quiet: false)
      pods(user: user, cached: cached, quiet: quiet).map { |p|
        p.container_specs.reduce({cpu: 0, memory: 0}) { |res, c|
          {
            cpu: res[:cpu] + c.cpu_request,
            memory: res[:memory] + c.memory_request
          }
        }
      }.reduce({cpu:0, memory: 0}) { |res, item|
        {
          cpu: res[:cpu] + item[:cpu],
          memory: res[:memory] + item[:memory]
        }
      }
    end

    def remaining_resources(user: nil, cached: true, quiet: false)
      requests_total = requests_total(user: user, cached: false, quiet: quiet)
      allocatable_cpu = allocatable_cpu(user: user, cached: cached, quiet: quiet)
      requests_total_cpu = requests_total[:cpu]
      allocatable_memory = allocatable_memory(user: user, cached: false, quiet: quiet)
      requests_total_mem = requests_total[:memory]

      {
        cpu: allocatable_cpu - requests_total_cpu,
        memory: allocatable_memory - requests_total_mem
      }
    end

    # calculate how many pods can be schedulable on the node
    # based on resources requested
    private def max_pod_count_capacity(user: nil, cached: true, quiet: false, **pod_requests)
      pod_requests.keys.map { | k |
        rr = remaining_resources(user: user, cached: cached, quiet: quiet)
        unless rr[k]
          raise "key #{k} is not supported currently"
        end
        rr[k] / pod_requests[k]
      }.min
    end

    # examples:
    # 1> max_pod_count_schedulable(cpu: convert_cpu("100m", memory: convert_to_bytes("100Mi"))
    # 2> max_pod_count_schedulable(cpu: convert_cpu("100m"))
    def max_pod_count_schedulable(user: nil, cached: true, quiet: false, **pod_requests)
      remaining_pods_count = allocatable_pods(user: user, cached: cached, quiet: quiet) -
        pods(user: user, cached: false, quiet: quiet).length
      return remaining_pods_count if pod_requests.empty?
      return [ max_pod_count_capacity(user: user, cached: false, quiet: quiet, **pod_requests), remaining_pods_count].min
    end
  end
end
