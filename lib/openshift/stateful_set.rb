require 'openshift/project_resource'

module BushSlicer
  # represnets an Openshift StatefulSets
  class StatefulSet < PodReplicator
    RESOURCE = "statefulsets"
    REPLICA_COUNTERS = {
      desired:   %w[spec replicas].freeze,
      current:   %w[status replicas].freeze
    }.freeze
    def abserve_generation(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'observedGeneration')
    end
  end
end
