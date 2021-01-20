require 'openshift/project_resource'

module BushSlicer
  class ArgoCD < ProjectResource
    RESOURCE = "argocds.argoproj.io"
  end
end
