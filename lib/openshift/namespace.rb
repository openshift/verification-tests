require 'openshift/cluster_resource'

module BushSlicer
  # represnets an Openshift Namespace
  class Namespace < ClusterResource
    RESOURCE = 'namespaces'

  end
end
