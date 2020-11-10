require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift Egress IP
  class EgressIp< ClusterResource
    RESOURCE = 'egressip'
  end
end
