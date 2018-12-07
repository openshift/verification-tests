require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift environment Network Policy
  class NetworkPolicy < ClusterResource
    RESOURCE = 'networkpolicies'
  end
end
