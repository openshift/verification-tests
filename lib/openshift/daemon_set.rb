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
  end
end
