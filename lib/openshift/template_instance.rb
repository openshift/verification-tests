require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift TemplateInstance
  class TemplateInstance < ProjectResource
    RESOURCE = "templateinstances"
  end
end
