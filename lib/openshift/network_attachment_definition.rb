require 'openshift/cluster_resource'

module BushSlicer
  # represents an Object
  class NetworkAttachmentDefinition < ClusterResource
    RESOURCE = 'networkattachmentdefinition.k8s.cni.cncf.io'

  end
end
