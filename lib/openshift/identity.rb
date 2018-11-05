require 'openshift/cluster_resource'

module BushSlicer
  # represents an OpenShift Identity
  class Identity < ClusterResource
    RESOURCE = 'identities'
  end
end
