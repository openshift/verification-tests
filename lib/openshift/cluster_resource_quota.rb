require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift cluster resource quota
  class ClusterResourceQuota < ClusterResource
    RESOURCE = 'clusterresourcequotas'
  end
end
