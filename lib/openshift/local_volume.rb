require 'openshift/project_resource'

module BushSlicer
  # represents LocalVolume CRD
  class LocalVolume < ProjectResource
    RESOURCE = 'localvolume'
  end
end
