require 'openshift/project_resource'

module BushSlicer
  class CustomResourceDefinition < ClusterResource
    RESOURCE = "customresourcedefinitions"
  end
end
