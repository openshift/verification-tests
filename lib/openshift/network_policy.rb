require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Network Policy
  class NetworkPolicy < ClusterResource
    RESOURCE = 'networkpolicies'
  end
end
