require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift (pvc for short)
  class LocalVolumeDiscovery < ProjectResource
    RESOURCE="localvolumediscovery.local.storage.openshift.io"

  end
end
