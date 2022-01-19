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
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      metrics = rr.dig('spec', 'metrics')
      cpu = metrics.find { |metric|
        metric.dig('resource', 'name') == 'cpu'
        return metric.dig('resource', 'target', 'averageUtilization')
      } unless metrics.nil? || rr.dig('spec', 'targetCPUUtilizationPercentage')
      return cpu.to_i
    end

    def current_cpu_utilization_percentage(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      metrics = rr.dig('status', 'currentMetrics')
      cpu = metrics.find { |metric|
        metric.dig('resource', 'name') == 'cpu'
        return metric.dig('resource', 'current', 'averageUtilization')
      } unless metrics.nil? || rr.dig('status', 'currentCPUUtilizationPercentage')
      return cpu.to_i
    end
  end
end
