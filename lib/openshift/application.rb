require 'openshift/project_resource'

module BushSlicer
  class Application < ProjectResource
    RESOURCE = "applications.argoproj.io"
  end
end
