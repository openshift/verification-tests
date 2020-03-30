require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift ConfigMap
  class AutomationBroker < ProjectResource
    RESOURCE = "automationbrokers"
  end
end
