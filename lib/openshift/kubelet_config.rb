require 'openshift/cluster_resource'

module BushSlicer
  class KubeletConfig < ClusterResource
    RESOURCE = "kubeletconfigs"
  end
end
