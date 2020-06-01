require 'openshift/cluster_resource'

module BushSlicer
  class ProjectConfigOpenshiftIo < ClusterResource
    RESOURCE = "project.config.openshift.io"
  end
end
