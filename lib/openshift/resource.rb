# TODO: frozen_string_literal: true

require 'yaml'
require 'common'
require 'openshift/resource_not_found_error'

module BushSlicer
  # @note represents a Resource / OpenShift API Object
  class Resource
    include Common::Helper
    extend  Common::BaseHelper

    # this needs to be set per sub class
    # represents the string we use with `oc get ...`
    # also represents string we use in REST call URL path
    # e.g. RESOURCE = "pods"

    attr_reader :props, :name
    attr_writer :default_user

    def annotation(annotation_name, user: nil, cached: true, quiet: false)
      raw_resource(user: user, quiet: quiet, cached: cached).
        dig("metadata", "annotations", annotation_name)
    end

    def uid(user: nil, cached: true, quiet: false)
      raw_resource(user: user, quiet: quiet, cached: cached).
        dig("metadata", "uid")
    end

    def created_at(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("metadata", "creationTimestamp")
    end
    alias created created_at

    def env
      raise "need to be implemented by subclass"
    end

    # @return [Boolean]
    def exists?(user: nil, result: {}, quiet: false)
      result.clear.merge!(get(user: user, quiet: quiet))
      if result[:success]
        return true
      elsif result[:response] =~ /not found/ or result[:response] =~ /doesn't have/
        return false
      # prevent premature exit as described in OCPQE-4351
      elsif result[:response] =~ /Unable to connect to the server/
        logger.info(result[:response])
        return false
      elsif result[:response] =~ /connection to the server \S+ was refused - did you specify the right host or port/ && env.nodes.length == 1
        logger.info(result[:response])
        return true
      else
        # e.g. when called by user without rights to list Resource
        raise "error getting #{self.class.name} '#{name}' existence: #{result[:response]}"
      end
    end

    def get_checked(user: nil, quiet: false)
      res = {}
      if exists?(user: user, quiet: quiet, result: res)
        return res
      else
        raise BushSlicer::ResourceNotFoundError,
          "#{self.class::RESOURCE} '#{name}' not found"
      end
    end

    def get(user: nil, quiet: false)
      user = default_user(user)

      get_opts = {
        resource_name: name,
        resource: self.class::RESOURCE,
        output: "yaml"
      }
      get_opts[:_quiet] = true if quiet

      if defined? project
        get_opts[:namespace] = project.name
      end

      res = user.cli_exec(:get, **get_opts)

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        update_from_api_object(res[:parsed])
      end

      return res
    end
    alias reload get

    # @param optional [Boolean] if true, then method will not raise for missing
    #   default user
    def default_user(user=nil, optional: false)
      if user
        user = env.admin if user == :admin
        self.default_user = user unless @default_user
        return user
      elsif @default_user
        return @default_user
      elsif !optional
        raise("must specify user for the operation")
      end
    end

    # update multiple API resources in as little calls as possible
    # @param user [User] the user to use for the API calls
    # @param resources [Array<Resource>]
    # @return [Array<Resource>] if any resources have not been found
    def self.bulk_update(user:, resources:, quiet: true)
      groups = resources.group_by(&:class).map(&:last)
      return groups.map { |group|
        group[0].class.bulk_update(user: user, resources: group, quiet: quiet)
      }.reduce([], :+)
    end

    # @param res [Hash] if caller wants to see result from the get call;
    #   note that it might not be updated if property returned from cache
    def get_cached_prop(prop:, user: nil, cached: false, quiet: false, res: nil)
      if res && cached
        raise "result cannot be returned with cached requests"
      end

      unless cached && props[prop]
        res ||= {}
        res.merge! get_checked(user: user, quiet: quiet)
      end

      return props[prop]
    end

    def raw_resource(user: nil, cached: true, quiet: false, res: nil)
      get_cached_prop(prop: :raw, user: user, cached: cached, quiet: quiet, res: res)
    end

    def cached?
      !!props[:raw]
    end

    def update_from_api_object(hash)
      case
      when hash["kind"] != kind
        raise "hash not from a #{shortclass}: expected #{kind} but was #{hash["kind"]}"
      when name != hash["metadata"]["name"]
        raise "hash from a different #{shortclass}: #{name} vs #{hash["metadata"]["name"]}"
      # TODO: check API name/version
      when self.respond_to?(:project) &&
           hash["metadata"]&.has_key?("namespace") &&
           project.name != hash["metadata"]["namespace"]
        raise "hash from a #{shortclass} of a different namespace '#{project}"
      end

      props.clear # remove any lazily initialized cached references to protect
      props[:raw] = Collections.deep_freeze(hash)

      return self # mainly to help ::from_api_object
    end

    # deleted object if it exists but does not wait for completion
    # @note subclasses need to implement #delete method
    def delete_graceful(by:)
      res = delete(by: by, wait: true)

      # this will actually fail for mising project when run by a regular user;
      # we can override this method in project.rb but I'm thinking that
      #  ensuring project deleted is not a regular user's job, just like
      #  user cannot ensure PVs are deleted
      res[:success] = res[:success] || res[:response].include?("not found")

      return res
    end

    def ensure_deleted(user: nil, wait: 60)
      res = delete_graceful(by: user)

      unless res[:success]
        raise "cannot delete #{self.class} #{name}"
      end

      if self.respond_to?(:delete_deps, true) && exists?(user: user, quiet: true)
        begin
          delete_deps(user: user, cached: false, quiet: true)&.each { |r|
            r.ensure_deleted(user: user, wait: wait)
          }
        rescue ResourceNotFoundError
          # most likely resource disappeared in the mean time
        end
      end

      unless disappeared?(user, wait)
        raise "#{self.class} #{name} did not disappear within #{wait} sec"
      end

      return res
    end

    # @return [BushSlicer::ResultHash]
    def wait_to_appear(user, seconds = 30)
      res = {}
      iterations = 0
      start_time = monotonic_seconds

      wait_for(seconds) {
        exists?(user: user, result: res, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return res
    end
    alias wait_to_be_created wait_to_appear

    # @return [Boolean]
    def disappeared?(user, seconds = 30)
      res = {}
      iterations = 0
      start_time = monotonic_seconds
      org_created_at = self.created_at if cached?

      success = wait_for(seconds) {
        exists?(user: user, result: res, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        if res[:success]
          # resource can be recreated, by creation timestamp we know original one is gone
          # note that first tried with UID but it didn't change for pods of stateful sets
          org_created_at ||= self.created_at
          org_created_at != self.created_at
        else
          true
        end
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return success
    end
    alias wait_to_disappear disappeared?

    # @return [Hash] the raw status of resource as returned by API
    def status_raw(user: nil, cached: false, quiet: false)
      raw_resource(user: user, quiet: quiet, cached: cached)["status"]
    end

    def phase(user: nil, cached: false, quiet: false)
      raw_status = status_raw(user: user, cached: cached, quiet: quiet)
      return raw_status ? raw_status["phase"].downcase.to_sym : nil
    rescue ResourceNotFoundError => e
      return :missing
    end

    def labels(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('metadata', 'labels')
    end

    # @param status [Symbol, Array<Symbol>] the expected statuses as a symbol
    # @return [ResultHash]
    def status?(user: nil, status:, quiet: false, cached: false)
      matched_status = phase(user: user, quiet: quiet, cached: cached)
      status = [ status ].flatten
      res = {
        instruction: "get #{cached ? 'cached' : ''} #{self.class::RESOURCE} #{name} status",
        response: "matched status for #{self.class::RESOURCE} #{name}: '#{matched_status}' while expecting '#{status}'",
        matched_status: matched_status,
        exitstatus: 0
      }

      #Check if the user-provided status actually exists
      if defined?(self.class::STATUSES)
        unknown_statuses = status - [:missing] - self.class::STATUSES
        unless unknown_statuses.empty?
          raise "some requested statuses are unknown: #{unknown_statuses}"
        end
      end
      res[:success] = status.include? matched_status
      return res
    end

    def conditions(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'conditions')
    end

    # returns a hash simliar to
    # {"lastTransitionTime"=>2019-03-23 07:33:34 UTC, "status"=>"False", "type"=>"Progressing"}
    def condition(type: nil, user: nil, cached: true, quiet: false)
      res = self.conditions(user: user, cached: cached, quiet: quiet).select { |c| c['type'] == type }
      res.first
    end

    # @note requires sub-class to define `#parse_oc_describe` method if
    #   parsing of the output is needed
    def describe(user=nil, quiet: false)
      user ||= default_user(user)

      if env != user.env
        raise "user and resource are from different environments"
      end

      resource_type = self.class::RESOURCE
      resource_name = name
      cli_opts = {
        name: resource_name,
        resource: resource_type,
        _quiet: quiet
      }

      cli_opts[:n] = project.name if self.respond_to?(:project)
      cli_opts[:_quiet] = quiet if quiet

      res = user.cli_exec(:describe, **cli_opts)
      if self.respond_to?(:parse_oc_describe)
        res[:parsed] = self.parse_oc_describe(res[:response]) if res[:success]
      end
      return res
    end

    # @return [BushSlicer::ResultHash] with :success true if we've eventually got
    #   the resource in ready status; the result hash is from last executed
    #   get call
    # @note sub-class needs to implement the `#ready?` method
    def wait_till_ready(user, seconds)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = ready?(user: user, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        unless ready_state_reachable?(user: user, cached: true, quiet: true)
          break
        end

        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return res
    end

    # waits until resource status is reached
    # @note this method requires sub-class to define the `#status?` method
    def wait_till_status(status, user, seconds)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = status?(user: user, status: status, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        # if build finished there's little chance to change status so exit early
        if !status_reachable?(res[:matched_status], status)
          break
        end
        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return res
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should also be true)
    # @note dummy class for generic use but better overload in sub-class
    def status_reachable?(from_status, to_status)
      true
    end

    # @param user [User, APIAccessor] user to execute any API calls as
    # @param cached [Boolean] whether to return cached state or not
    # @param quiet [Boolean] whether to produce console output from executed
    #   operations
    # @return [Boolean] whether it is possible for the object to ever become
    #   ready
    # @note this is a dummy method, each class that cares should override
    def ready_state_reachable?(user: nil, cached: true, quiet: false)
      true
    end

    # TODO: implement fallback `#status?` method

    def self.shortclass
      self.name.split("::").last
    end

    def shortclass
      self.class.shortclass
    end

    # @return [String] the resource name without the API name, e.g.
    #   for `configs.samples.operator.openshift.io` it will return `configs`
    def self.resource_link_element
      @resource_link_element ||= self::RESOURCE[/^[^.]*/].freeze
    end

    # @return [String] the type of resource as would appear in YAML output
    # @note we need to handle resources where api name part is significant and
    #   RESOURCE contains dots
    def self.kind
      unless @kind
        if self::RESOURCE.count(".").zero?
          # old style, missing api name
          @kind = shortclass
        elsif shortclass.size <= resource_link_element.size + 2
          # class name doesn't contain API name but RESOURCE does

          # Class name is always singular, `resource_link_element` is always
          # plural. I found only one plural word that is 2 chars shorter than
          # singular but in RESOURCE containing API name, there is at least
          # one dot + some characters. I think there can't be any API name
          # with less than 2 characters, so the above check should cover all
          # practical cases.
          # In the unlikely case some resource doesn't fit this check,
          # one can override this method for it.
          @kind = shortclass
        else
          # full API name in RESOURCE, class name also include api name
          resource_without_dots = self::RESOURCE.gsub(".", "")
          api_name_no_dots = resource_without_dots[resource_link_element.size..-1]
          @kind = shortclass[/.*?(?=#{api_name_no_dots}\z)/i]
          if @kind.nil?
            raise "#{shortclass}: error in class definition, RESOURCE and class name mismatch"
          end
        end
      end

      return @kind
    end

    def kind
      self.class.kind
    end

    def self.struct_iso8601_time(struct)
      Collections.deep_map_hash(struct) do |k, v|
        case v
        when Time
          [k, v.iso8601]
        when Array
          [
            k,
            v.map {|v| self.struct_iso8601_time(v)}
          ]
        else
          [k, v]
        end
      end
    end

    ############### take care of object comparison ###############
    def ==(resource)
      raise "need to be implemented by subclass"
    end
    alias eql? ==

    def hash
      raise "need to be implemented by subclass"
    end
  end
end
