require 'openshift/cluster_resource'

module BushSlicer
  class KubeletConfig < ClusterResource
    RESOURCE = "kubeletconfigs.machineconfiguration.openshift.io"
  end
end
