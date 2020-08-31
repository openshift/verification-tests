require 'openshift/project_resource'

module BushSlicer
  class ThanosRuler < ProjectResource
    RESOURCE = "thanosrulers.monitoring.coreos.com"
  end
end