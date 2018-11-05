require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Host Subnet
  class HostSubnet < ClusterResource
    RESOURCE = 'hostsubnets'

    def ip(user: nil, cached: true, quiet: true)
      raw = raw_resource(user: user, cached: cached, quiet: quiet, res: nil)
      raw['hostIP']
    end

    def host(user: nil, cached: true, quiet: true)
      raw = raw_resource(user: user, cached: cached, quiet: quiet, res: nil)
      raw['host']
    end

    def subnet(user: nil, cached: true, quiet: true)
      raw = raw_resource(user: user, cached: cached, quiet: quiet, res: nil)
      raw['subnet']
    end
  end
end
