require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Network class
  class Network < ClusterResource

    def cluster_network(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'clusterNetwork')
    end

  end

  class NetworkOperator < Network
    RESOURCE = "networks.operator.openshift.io"
    def network_type(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'defaultNetwork', 'type')
    end
  end

  class NetworkConfig < Network
    RESOURCE = "networks.config.openshift.io"
    def network_type(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'networkType')
    end
    def cluster_network_mtu(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'clusterNetworkMTU')
    end


  end
end
