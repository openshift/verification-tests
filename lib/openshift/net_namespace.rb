require 'openshift/cluster_resource'

module BushSlicer
  # represnets an Openshift NetNamespace
  class NetNamespace < ClusterResource
    RESOURCE = 'netnamespaces'

    def annotations(user: env.admin, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'annotations')
    end
  end
end
