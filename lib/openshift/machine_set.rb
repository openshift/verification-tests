require 'openshift/cluster_resource'

module BushSlicer
  # represents MachineSet
  class MachineSet < ProjectResource
    RESOURCE = 'machinesets'

    def desired_replicas(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'replicas').to_i
    end

    def available_replicas(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'availableReplicas').to_i
    end

    def ready?(user: nil, cached: false, quiet: false)
      result = {}
      result[:success] = (desired_replicas(user: user, cached: cached, quiet: quiet) ==
        available_replicas(user: user, cached: cached, quiet: quiet))
      return result
    end

    def cluster(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'selector', 'matchLabels', 'machine.openshift.io/cluster-api-cluster')
    end
  end
end
