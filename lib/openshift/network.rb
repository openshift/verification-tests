require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Storage Class
  class Network < ClusterResource
    RESOURCE = "networks"

    def network_type(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'networkType')
    end

  end
end
