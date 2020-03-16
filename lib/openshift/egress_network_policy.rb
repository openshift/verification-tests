require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift Egress Network Policy
  class EgressNetworkPolicy < ClusterResource
    RESOURCE = 'egressnetworkpolicies'
  end
end
