require 'openshift/cluster_resource'

module BushSlicer
    class ClusterNetwork < ClusterResource
        RESOURCE = "clusternetworks"
        def plugin_name(user: nil, cached: true, quiet: false)
            rr = raw_resource(user: user, cached: cached, quiet: quiet)
            return rr.dig('pluginName')
        end
    end
end
