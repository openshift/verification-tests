# frozen_string_literal: true

require 'openshift/project_resource'
require 'active_support/core_ext/hash/slice'
require 'base_helper'

module BushSlicer
  class PodReplicator < ProjectResource

    ## must be defined in subclasses
    # REPLICA_COUNTERS = {
    #   counter_name: %w[path to dig].freeze,
    # }.freeze

    # for eval vs define_method check:
    #   http://graysoftinc.com/ruby-tutorials/eval-isnt-quite-pure-evil
    def method_missing(meth, *args, &block)
      meths = meth.to_s
      if meths.end_with?("_replicas") &&
          self.class::REPLICA_COUNTERS.keys.include?(meths[0...-9].to_sym)
        self.class::REPLICA_COUNTERS.keys.each do |counter|
          self.class.class_eval do
            eval <<-END_COUNTERS
              def #{counter}_replicas(user: nil, cached: true, quiet: false)
                replica_counters(user: user, cached: cached, quiet: quiet).
                  fetch(:#{counter}, 0)
              end
            END_COUNTERS
          end
        end
        return send(meth, *args, &block)
      else
        super
      end
    end

    def replica_counters(user: nil, cached: true, quiet: false, res: nil)
      resource = raw_resource(user: user, quiet: quiet, res: res, cached: cached)
      self.class::REPLICA_COUNTERS.map do |counter, path|
        [counter, resource.dig(*path).to_i]
      end.to_h.freeze
    end

    def wait_till_replica_counters_match(user:, seconds:, **options)
      expected = options.slice(*self.class::REPLICA_COUNTERS.keys)

      stats = {}
      result = {
        instruction: "wait till deployment #{name} reaches matching count",
        success: false,
      }

      result[:success] = wait_for(seconds, stats: stats) do
        counters = replica_counters(user: user, quiet: true,
                                    cached: false, res: result)
        counters.slice(*expected.keys) == expected
      end

      logger.info "After #{stats[:iterations]} iterations\n" \
        "and #{stats[:full_seconds]} seconds:\n" \
        "#{replica_counters(user: user, quiet: true).inspect}"

      unless result[:success]
        logger.warn "#{shortclass}: timeout waiting for replica counters " \
          "to match; last state:\n\$ #{result[:command]}\n#{result[:response]}"
      end
      return result
    end

    def revision(user:, cached: true, quiet: false)
      annotation('deployment.kubernetes.io/revision',
        user: user, cached: cached, quiet: quiet)
    end

    ################### container spec related methods ####################
    def template(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "template")
    end

    # translate template containers into ContainerSpec object
    def containers_spec(user: nil, cached: true, quiet: false)
      specs = []
      containers_spec = template(user: user, cached: cached, quiet: quiet)['spec']['containers']
      containers_spec.each do | container_spec |
        specs.push ContainerSpec.new container_spec
      end
      return specs
    end

    # return the spec for a specific container identified by the param name
    def container_spec(user: nil, name:, cached: true, quiet: false)
      specs = containers_spec(user: user, cached: cached, quiet: quiet)
      target_spec = {}
      specs.each do | spec |
        target_spec = spec if spec.name == name
      end
      raise "No container spec found matching '#{name}'!" if target_spec.is_a? Hash
      return target_spec
    end

    private def volumes_raw(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet)['spec']['volumes']
    end

    # @return [Array<PodVolumeSpec>]
    def volumes(user: nil, cached: true, quiet: false)
      unless cached && props[:volume_specs]
        raw = volumes_raw(user: user, cached: cached, quiet: quiet) || []
        props[:volume_specs] = raw.map {|vs| PodVolumeSpec.from_spec(vs, self) }
      end
      return props[:volume_specs]
    end

    def tolerations(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet).dig('spec', 'tolerations')
    end

  end
end
