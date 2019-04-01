require 'openshift/cluster_resource'

module BushSlicer
  class KubeAPIServer < ClusterResource
    RESOURCE = 'kubeapiservers'
  end
end
