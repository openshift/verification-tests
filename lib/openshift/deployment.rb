# frozen_string_literal: true

require 'openshift/pod_replicator'

# TODO: DRY together with replica_set.rb

module BushSlicer

  # represents an Openshift Deployment
  class Deployment < PodReplicator

    RESOURCE = 'deployments'
    REPLICA_COUNTERS = {
      desired:   %w[spec replicas].freeze,
      current:   %w[status replicas].freeze,
      updated:   %w[status updatedReplicas].freeze,
      available: %w[status availableReplicas].freeze,
      ready: %w[status readyReplicas].freeze,
    }.freeze

    # we define this in method_missing so alias can't fly
    # alias replica_count current_replicas
    def replica_count(*args, &block)
      current_replicas(*args, &block)
    end
    alias replicas replica_count

    def strategy(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "strategy")
    end

    def current_replica_set(user:, cached: true, quiet: false)
      shared_options = { user: user, cached: true, quiet: quiet }.freeze

      labels = match_labels(**shared_options, cached: cached)
      revision = self.revision(**shared_options)

      BushSlicer::ReplicaSet.get_labeled(*labels, user: user, project: project)
        .select { |item| item.revision(**shared_options) == revision }
        .max_by { |item| item.created_at(**shared_options) }
    end

    MATCH_LABELS_DIG_PATH = %w[spec selector matchLabels].freeze
    private_constant :MATCH_LABELS_DIG_PATH

    def match_labels(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig(*MATCH_LABELS_DIG_PATH)
    end

    def collision_count(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'collisionCount')
    end

    def generation_number(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('metadata', 'generation')
    end

    def pod_selector(user: nil, cached: true, quiet: false)
      raw_labels = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'template', 'metadata', 'labels')
      arr = []
      raw_labels.each do |key, value|
        arr.push(key + "=" + value)
      end
      return arr
    end

    def node_selector(user: nil, cached: false, quiet: false)
      template(user: user, cached: cached, quiet: quiet).dig('spec', 'nodeSelector')
    end

    def containers(user: nil, cached: true, quiet: false)
      template(user: user, cached: cached, quiet: quiet).dig('spec', 'containers')
    end

  end
end
