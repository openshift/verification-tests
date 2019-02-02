require 'openshift/project_resource'

module BushSlicer
  class CustomResourceDefinition < ProjectResource
    RESOURCE = "customresourcedefinitions"
  end
end
