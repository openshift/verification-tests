require 'openshift/cluster_resource'

module BushSlicer
  class NodeFeatureDiscovery < ClusterResource
    RESOURCE = 'nodefeaturediscoveries.nfd.openshift.io'
  end
end
