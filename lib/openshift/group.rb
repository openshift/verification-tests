require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Group
  class Group < ClusterResource
    RESOURCE = 'groups'
  end
end
