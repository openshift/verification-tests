require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift environment Group
  class Group < ClusterResource
    RESOURCE = 'groups'
  end
end
