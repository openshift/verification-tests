require 'openshift/project_resource'

module BushSlicer
  # represents LocalVolume CRD
  class LocalVolumeLocalStorageOpenshiftIo < ProjectResource
    RESOURCE = 'localvolume.local.storage.openshift.io'
  end
end
