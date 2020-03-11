require 'openshift/project_resource'

module BushSlicer
  class PrometheusRule < ProjectResource
    RESOURCE = "prometheusrules"
  end
end
