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
      cpu_pct = rr.dig('spec', 'targetCPUUtilizationPercentage')
      return cpu_pct.to_i unless cpu_pct.nil?

      metrics = rr.dig('spec', 'metrics')
      metric = metrics.find { |metric|
        metric.dig('resource', 'name') == 'cpu'
      } unless metrics.nil?
      avg_utl = metric.dig('resource', 'target', 'averageUtilization') unless metric.nil?
      return avg_utl.to_i
    end

    def current_cpu_utilization_percentage(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      cpu_pct = rr.dig('status', 'currentCPUUtilizationPercentage')
      return cpu_pct.to_i unless cpu_pct.nil?

      metrics = rr.dig('status', 'currentMetrics')
      metric = metrics.find { |metric|
        metric.dig('resource', 'name') == 'cpu'
      } unless metrics.nil?
      avg_utl = metric.dig('resource', 'current', 'averageUtilization') unless metric.nil?
      return avg_utl.to_i
    end
  end
end
