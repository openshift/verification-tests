require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Network class

  class NetworkOperator < ClusterResource
    # full network.operator.openshift.io name doesn't seem to work,
    # RuntimeError: hash not from a NetworkOperator: expected  but was Network
    # raise "hash not from a #{shortclass}: expected #{kind} but was #{hash["kind"]}"
    # api_name_no_dots = "operatoropenshiftio"
    # resource_without_dots = "networksoperatoropenshiftio"
    # lib/openshift/config_imageregistry_operator_openshift_io.rb` - for objects without unique name and you need full qualified name
    RESOURCE = "network.operator"

    def network_type(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'defaultNetwork', 'type')
    end

    def cluster_network(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'clusterNetwork')
    end

    def ovn_kubernetes_config(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'defaultNetwork', 'ovnKubernetesConfig')
    end

  end

end
