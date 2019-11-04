require 'openshift/cluster_resource'

module BushSlicer
  # represnets an Openshift Namespace
  class Networkattachmentdefinition < ClusterResource
    RESOURCE = 'networkattachmentdefinition.k8s.cni.cncf.io'

  end
end
