require 'yaml'
require 'host'

require_relative 'resource'

module BushSlicer
  # @note represents a Resource / OpenShift API Object
  class ClusterResource < Resource

    attr_reader :env

    def initialize(name:, env:)

      if name.nil? || env.nil?
        raise "ClusterResource needs name and environment to be identified"
      end

      @name = name.freeze
      @env = env
      @props = {}
    end

    def default_user(user=nil, optional: false)
      super(user, optional: true) || super(env.admin)
    end

    # creates a new OpenShift Cluster Resource from spec
    # @param by [BushSlicer::APIAccessorOwner, BushSlicer::APIAccessor] the user to create
    #   Resource as
    # @param spec [String, Hash] the Hash representaion of the API object to
    #   be created or a String path of a JSON/YAML file
    # @return [BushSlicer::ResultHash]
    # @note unify with ProjectResource and remove opts parameter
    def self.create(by:, spec:, **opts)
      if spec.kind_of? String
        # assume a file path (TODO: be more intelligent)
        spec = YAML.load_file(spec)
      end
      name = spec["metadata"]["name"] || raise("no name specified for resource")
      init_opts = {name: name, env: by.env}

      res = by.cli_exec(:create,
                        f: '-',
                        _stdin: self.struct_iso8601_time(spec).to_json,
                        **opts)
      res[:resource] = self.new(**init_opts)

      return res
    end

    # creates new resource from an OpenShift API Project object
    def self.from_api_object(env, resource_hash)
      unless Environment === env
        raise "env parameter must be an Environment but is: #{env.inspect}"
      end
      self.new(env: env, name: resource_hash["metadata"]["name"]).
                                update_from_api_object(resource_hash)
    end

    # @param reference [ObjectReference]
    # @param referer [Resource]
    # @return [ClusterResource]
    def self.from_reference(reference, referer)
      resource = self.class.new(name: reference.name, env: referer.env)
      begin
        resource.default_user(reference.default_user(optional: true))
      rescue UnsupportedOperationError
        # perhaps referer is a resource without default user set,
        # but environment does not support admin access
      end

      return resource
    end
    # update multiple API resources in as little calls as possible
    # @param user [User] the user to use for the API calls
    # @param resources [Array<ClusterResource>]
    # @return [Array<ClusterResource>] if any resources have not been found
    def self.bulk_update(user:, resources:, quiet: true)
      resources.group_by(&:class).map(&:last).map do |group|
        group[0].class.list(user: user, get_opts: {_quiet: quiet}) do |resource, resource_hash|
          group.delete(resource)&.update_from_api_object(resource_hash)
        end
        group
      end.reduce([], :+)
    end

    # @param labels [String, Array<String,String>] labels to filter on, read
    #   [BushSlicer::Common::BaseHelper#selector_to_label_arr] carefully
    # @param count [Integer] minimum number of resources to wait for
    def self.wait_for_labeled(*labels, count: 1, user:, seconds:)
      wait_for_matching(user: user, seconds: seconds,
                        get_opts: {l: selector_to_label_arr(*labels)},
                        count: count) do |item, item_hash|
                          !block_given? || yield(item, item_hash)
      end
    end

    # @param count [Integer] minimum number of items to wait for
    # @yield block that selects items by returning true; see [#get_matching]
    # @return [BushSlicer::ResultHash] with :matching key being array of matched
    #   resource items;
    def self.wait_for_matching(count: 1, user:, seconds:, get_opts: [])
      res = {}

      quiet = get_opts.find {|k,v| k == :_quiet}
      if quiet
        # TODO: we may think about `:false` string value if passed by a step
        quiet = quiet[1]
      else
        quiet = true
        get_opts = get_opts.to_a << [:_quiet, true]
      end

      stats = {}
      wait_for(seconds, interval: 3, stats: stats) {
        get_matching(user: user, result: res, get_opts: get_opts) { |resource, resource_hash|
          yield resource, resource_hash
        }
        res[:success] = res[:matching].size >= count
      }

      if quiet
        # user didn't see any output, lets print used command
        user.env.logger.info res[:command]
      end
      user.env.logger.info "#{stats[:iterations]} iterations for #{stats[:full_seconds]} sec, returned #{res[:items].size} #{self::RESOURCE}, #{res[:matching].size} matching"

      return res
    end
    # @param labels [String, Array<String,String>] labels to filter on, read
    #   [BushSlicer::Common::BaseHelper#selector_to_label_arr] carefully
    # @return [Array<ProjectResource>] with :matching key being array of matched
    #   resources
    def self.get_labeled(*labels, user:, result: {}, quiet: false)
      get_opts = {l: selector_to_label_arr(*labels)}
      get_opts[:_quiet] = true if quiet
      get_matching(user: user, result: result,
                   get_opts: get_opts) do |r, r_hash|
        !block_given? || yield(r, r_hash)
      end
    end
    # list resources by a user
    # @param user [BushSlicer::User] the user we list resources as
    # @param result [ResultHash] can be used to get full result hash from op
    # @param get_opts [Hash, Array] other options to pass down to oc get
    # @return [Array<ClusterResource>]
    # @note raises error on issues
    def self.get_matching(user:, result: {}, get_opts: [])
      # construct options
      opts = [ [:resource, self::RESOURCE],
               [:output, "yaml"]
      ]
      get_opts.each { |k,v|
        if [:resource, :output, :o, :resource_name,
            :w, :watch, :watch_only, :n, :namespace].include?(k)
          raise "incompatible option #{k} provided in get_opts"
        else
          opts << [k, v]
        end
      }

      res = result
      res.merge! user.cli_exec(:get, opts)
      if res[:success]
        # oc 3.5 returns "No resources found." in stderr so we need to ignore it
        res[:parsed] = YAML.load(res[:stdout])
        res[:items] = res[:parsed]["items"].map { |item_hash|
          self.from_api_object(user.env, item_hash)
        }
      elsif res[:stderr] =~ /Error from server \(ServiceUnavailable\)\: the server is currently unable to handle the request \(get projects\.project\.openshift\.io/
          # refer to https://github.com/openshift/verification-tests/pull/2823
          logger.info(">>>>>> Debug Segment: checking openshift-apiserver availability <<<<<<")
          logger.info(res[:stderr])
          # get debug kubeconfig
          user.env.admin # HACK: force reload kubeconfig
          debug_kubeconfig_path = File.join(Host.localhost.workdir, "debug.kubeconfig")
          # debug messages
          debug_message = host.exec("oc get co --kubeconfig=#{debug_kubeconfig_path} | grep -v '.True.*False.*False'")
          logger.info(debug_message)
          debug_message = host.exec("oc describe co/openshift-apiserver --kubeconfig=#{debug_kubeconfig_path} | sed -n \"/Status:/,$ p\"")
          logger.info(debug_message)
      else
        user.env.logger.error(res[:response])
        raise "error getting #{self::RESOURCE} by user: '#{user}'"
      end

      res[:matching] = []
      res[:items].zip(res[:parsed]["items"]) { |i, i_hash|
        res[:matching] << i if !block_given? || yield(i, i_hash)
      }

      return res[:matching]
    end
    class << self
      alias list get_matching
    end

    def delete(by: nil, wait: false)
      default_user(by).cli_exec(:delete, object_type: self.class::RESOURCE,
               object_name_or_id: name, wait: "#{wait}")
    end

    ############### take care of object comparison ###############
    def ==(p)
      p.kind_of?(self.class) && name == p.name && env == p.env
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ name.hash ^ env.hash
    end

    ################# make pry inspection nicer ##################
    def inspect
      "#<#{self.class} #{env.key}/#{name}>"
    end
  end
end
