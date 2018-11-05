# frozen_string_literal: true

require 'openshift/pod_replicator'

# TODO: DRY together with deployment.rb

module BushSlicer

  # represents an Openshift ReplicaSets (rs for short)
  class ReplicaSet < PodReplicator

    RESOURCE = 'replicasets'
    REPLICA_COUNTERS = {
      desired: %w[spec replicas].freeze,
      current: %w[status replicas].freeze,
      ready:   %w[status readyReplicas].freeze,
    }.freeze

    # we define this in method_missing so alias can't fly
    # alias replica_count current_replicas
    def replica_count(*args, &block)
      current_replicas(*args, &block)
    end
    alias replicas replica_count

  end
end
