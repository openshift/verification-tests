require 'openshift/cluster_resource'

module BushSlicer
  # represents MachineSet
  class MachineSet < ProjectResource
    RESOURCE = 'machinesets'

    def desired(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'replicas')
    end

    def current(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'replicas')
    end

    def healthy?
      return desired == current
    end
  end
end
