require 'openshift/cluster_resource'

module BushSlicer
  class ImagePrunerImageregistryOperatorOpenshiftIo < ClusterResource
    RESOURCE = 'imagepruners.imageregistry.operator.openshift.io'
  end
end
