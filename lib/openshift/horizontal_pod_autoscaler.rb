require 'openshift/pod_replicator'

module BushSlicer
  # represents an OpenShift Image Stream
  class HorizontalPodAutoscaler < PodReplicator
    RESOURCE = "horizontalpodautoscalers"

    REPLICA_COUNTERS = {
      max: %w[spec maxReplicas].freeze,
      min: %w[spec minReplicas].freeze,
      current: %w[status currentReplicas].freeze,
    }.freeze

    def target_cpu_utilization_percentage(user: nil, cached: true, quiet: false)
      obj = raw_resource(user: user, cached: cached, quiet: quiet)
      return obj.dig('spec', 'targetCPUUtilizationPercentage')
    end

    def current_cpu_utilization_percentage(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('status', 'currentCPUUtilizationPercentage').
        to_i # it can be nil when zero thus using #to_i
    end
  end
end
