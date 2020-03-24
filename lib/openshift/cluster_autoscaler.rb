require 'openshift/cluster_resource'

module BushSlicer
  # represents ClusterAutoscaler
  class ClusterAutoscaler < ClusterResource
    RESOURCE = "clusterautoscaler"
  end
end
