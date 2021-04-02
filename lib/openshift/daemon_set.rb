require 'openshift/pod_replicator'

module BushSlicer
  # represnets an Openshift StatefulSets
  class DaemonSet < PodReplicator
    RESOURCE = "daemonsets"

    # all these counters are accessible as method calls
    # see implementation in PodReplicator#method_missing
    # e.g. ds.misscheduled_replicas(cached: false)
    REPLICA_COUNTERS = {
      desired: %w[status desiredNumberScheduled].freeze,
      current: %w[status currentNumberScheduled].freeze,
      ready:   %w[status numberReady].freeze,
      updated_scheduled: %w[status updatedNumberScheduled].freeze,
      misscheduled: %w[status numberMisscheduled].freeze,
      available: %w[status numberAvailable].freeze,
    }.freeze

    def generation_number(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('metadata', 'generation')
    end

    def node_selector(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet).
        dig("spec", "nodeSelector")
    end

    def selector(user: nil, quiet: false, cached: true)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "selector")
    end

    # @return [Array<Pod>]
    def pods(user: nil, quiet: false, cached: true, result: {})
      unless cached && props[:pods]
        selector = selector(user: user, cached: false, quiet: quiet)
        if ! Hash === selector || selector.empty?
          raise "can't tell if ready for services without pod selector"
        end

        case
        when selector.keys.first == "matchLabels"
          labels = selector["matchLabels"]
        else
          raise "not implementing getting pods with selector #{selector}"
        end

        props[:pods] = Pod.get_labeled(*labels,
                                       user: default_user(user),
                                       project: project,
                                       quiet: quiet,
                                       result: result)
      end
      return props[:pods]
    end

    def creation_time_stamp(user: nil, quiet: false, cached: true)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("metadata", "creationTimestamp")
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
  end
end
