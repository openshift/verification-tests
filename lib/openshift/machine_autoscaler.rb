require 'openshift/cluster_resource'

module BushSlicer
  class MachineAutoscaler < ProjectResource
    RESOURCE = 'machineautoscaler'

    def minreplicas(user: nil, cached: true, quiet: false)
    	rr = raw_resource(user: user, cached: cached, quiet: quiet)
    	return rr.dig('spec', 'minReplicas')
    end

    def maxreplicas(user: nil, cached: false, quiet: false)
    	rr = raw_resource(user: user, cached: cached, quiet: quiet)
    	return rr.dig('spec', 'maxReplicas')
    end

    def scaletargetref(user: nil, cached: false, quiet: false)
    	rr = raw_resource(user: user, cached: cached, quiet: quiet)
    	return rr.dig('spec', 'scaleTargetRef')
    end
    
  end
end