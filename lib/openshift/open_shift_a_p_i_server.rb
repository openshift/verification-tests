require 'openshift/cluster_resource'

module BushSlicer
  class OpenShiftAPIServer < ClusterResource
    RESOURCE = 'openshiftapiservers'
  end
end
