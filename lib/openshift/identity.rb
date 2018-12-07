require 'openshift/cluster_resource'

module VerificationTests
  # represents an OpenShift Identity
  class Identity < ClusterResource
    RESOURCE = 'identities'
  end
end
