require 'json'
require 'yaml'

require 'openshift/resource'

module BushSlicer
  # @note represents an OpenShift namespaced Resource (part of a Project)
  class ProjectResource < Resource
    attr_reader :project

    # RESOURCE = "define me"

    # @param name [String] name of the resource
    # @param project [BushSlicer::Project] the project we belong to
    # @param props [Hash] additional properties of the resource
    def initialize(name:, project:)
      unless String === name
        raise "name should be a string but it is #{name.inspect}"
      end
      unless Project === project
        raise "name should be a Project but it is #{project.inspect}"
      end
      @name = name
      @project = project
      @props = {}
    end

    def env
      project.env
    end

    # creates a new OpenShift Project Resource via API
    # @param by [BushSlicer::APIAccessorOwner, BushSlicer::APIAccessor] the user to create
    #   ProjectResource as
    # @param project [BushSlicer::Project] the namespace for the new resource
    # @param spec [String, Hash] the Hash object to create project resource or
    #   a String path of a JSON/YAML file
    # @return [BushSlicer::ResultHash]
    def self.create(by:, project:, spec:, **opts)
      if spec.kind_of? String
        # assume a file path (TODO: be more intelligent)
        case spec
        when %r{https?://}
          spec = YAML.load(Http.get(url: spec, raise_on_error: true)[:response])
        else
          spec = YAML.load_file(spec)
        end
      end
      name = spec["metadata"]["name"]
      # TODO: verify resource type and metadata/namespace!

      res = by.cli_exec(:create,
                        n: project.name,
                        f: '-',
                        _stdin: self.struct_iso8601_time(spec).to_json,
                        **opts)
      res[:resource] = self.new(name: name, project: project)
      res[:resource].default_user = by

      return res
    end

    # creates new ProjectResource from an OpenShift API object hash
    def self.from_api_object(project, resource_hash)
      self.new(project: project, name: resource_hash["metadata"]["name"]).
                                update_from_api_object(resource_hash)
    end

    # @param reference [ObjectReference]
    # @param referer [Resource]
    # @return [ProjectResource]
    # @note that a cluster resource may refer to a project resource as well
    #   a project resource may refer resources from another project
    def self.from_reference(reference, referer)
      referer_project = referer.project if referer.respond_to?(:project)
      if referer_project &&
          (!reference.namespace || referer_project.name == reference.namespace)
        project = referer_project
      else
        project = Project.new(name: reference.namespace, env: referer.env)
      end

      resource = self.new(name: reference.name, project: project)
      begin
        resource.default_user(referer.default_user(optional: true),
                              optional: true)
      rescue UnsupportedOperationError
        # perhaps referer is a cluster resource without default user set,
        # but environment does not support admin access
      end

      return resource
    end

    # update multiple API resources in as little calls as possible
    # @param user [User] the user to use for the API calls
    # @param resources [Array<ProjectResource>]
    # @return [Array<ProjectResource>] if any resources have not been found
    def self.bulk_update(user:, resources:, quiet: true)
      resources.group_by(&:class).map(&:last).map do |group_by_class|
        group_by_class.group_by(&:project).map(&:last).map do |group|
          group[0].class.list(
            user: user,
            project: group[0].project,
            get_opts: [_quiet: quiet]
          ) do |resource, resource_hash|
            group.delete(resource)&.update_from_api_object(resource_hash)
          end
          group
        end.reduce([], :+)
      end.reduce([], :+)
    end

    # @param grace_period [Boolean] useful to add the pod delete parameter
    def delete(by: nil, grace_period: nil, wait: false)
      by = default_user(by)
      del_opts = {}
      del_opts[:grace_period] = grace_period unless grace_period.nil?
      by.cli_exec(:delete, object_type: self.class::RESOURCE,
               object_name_or_id: name, namespace: project.name,
               wait: "#{wait}", **del_opts)
    end

    # @param labels [String, Array<String,String>] labels to filter on, read
    #   [BushSlicer::Common::BaseHelper#selector_to_label_arr] carefully
    # @param count [Integer] minimum number of resources to wait for
    def self.wait_for_labeled(*labels, count: 1, user:, project:, seconds:)
      wait_for_matching(user: user, project: project, seconds: seconds,
                        get_opts: {l: selector_to_label_arr(*labels)},
                        count: count)  do |item, item_hash|
                          !block_given? || yield(item, item_hash)
      end
    end

    # @param count [Integer] minimum number of items to wait for
    # @yield block that selects items by returning true; see [#get_matching]
    # @return [BushSlicer::ResultHash] with :matching key being array of matched
    #   resource items;
    def self.wait_for_matching(count: 1, user:, project:, seconds:,
                                                                  get_opts: [])
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
        get_matching(user: user, project: project, result: res, get_opts: get_opts) { |resource, resource_hash|
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
    def self.get_labeled(*labels, user:, project:, result: {}, quiet: false)
      get_opts = {l: selector_to_label_arr(*labels)}
      get_opts[:_quiet] = true if quiet
      get_matching(user: user, project: project, result: result,
                   get_opts: get_opts) do |r, r_hash|
        !block_given? || yield(r, r_hash)
      end
    end

    # @param project [Project, :all] when project is any, we list all namespaces
    # @yield block that selects resource items by returning true; block receives
    #   |resource, resource_hash| as parameters where resource is a reloaded
    #   [Resource] sub-type, e.g. [Pod], [Build], etc.
    # @return [Array<ProjectResource>]
    def self.get_matching(user:, project:, result: {}, get_opts: [])
      # construct options
      opts = [ [:resource, self::RESOURCE],
               [:output, "yaml"],
      ]

      case project
      when Project
        opts << [:n, project.name]
      when :all
        opts << [:all_namespaces, "true"]
      else
        raise "unrecognized project specification: #{project.inspect}"
      end

      get_opts.each { |k,v|
        if [:resource, :n, :namespace, :resource_name,
            :w, :watch, :watch_only].include?(k)
          raise "incompatible option #{k} provided in get_opts"
        elsif [:output, :o].include?(k) && !["json", "yaml"].include?(v)
          raise "output can only be JSON or YAML but is: #{v}"
        else
          opts << [k, v]
        end
      }

      res = result
      res.merge! user.cli_exec(:get, opts)

      if res[:success]
        # oc 3.5 returns "No resources found." in stderr so we need to ignore it
        res[:parsed] = YAML.load(res[:stdout])
        if Project === project
          res[:items] = res[:parsed]["items"].map { |i|
            self.from_api_object(project, i)
          }
        else
          res[:items] = []
          res[:parsed]["items"].
            group_by { |i| i["metadata"]["namespace"]}.each { |namespace, items|
              _project = Project.new(name: namespace, env: user.env)
              items.each {|i| res[:items] << self.from_api_object(_project, i) }
            }
        end
      else
        user.env.logger.error(res[:response])
        raise "cannot get #{self::RESOURCE} for project #{project.name}"
      end

      res[:matching] = []
      res[:items].zip(res[:parsed]["items"]) { |i, i_hash|
        if !block_given? || yield(i, i_hash)
          i.default_user = user
          res[:matching] << i
        end
      }

      return res[:matching]
    end
    class << self
      alias list get_matching
    end

    def owner_references(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'ownerReferences')
    end

    # recursively call itself until there is no ownerReference
    def walk_owner_references(user: nil, resource_type: nil, resource_name: nil, cached: true, quiet: false)
      logger.info("resource_type: #{resource_type}, resource_name: #{resource_name}")
      res = owner_references(user: user)
      if res
        r_type = res.first['kind']
        r_name = res.first['name']
        clazz = Object.const_get("::BushSlicer::#{r_type}")
        rc = clazz.new(name: r_name, project: project)
        resource_type, resource_name = rc.walk_owner_references(user: user, resource_type: r_type, resource_name: r_name, cached: cached,  quiet: quiet)
      end
      return resource_type, resource_name
    end
    ############### take care of object comparison ###############

    def ==(p)
      p.kind_of?(self.class) && name == p.name && project == p.project
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ name.hash ^ project.hash
    end
  end
end
