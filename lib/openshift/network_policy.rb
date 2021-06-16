require 'openshift/project_resource'

module BushSlicer
  # @note represents an OpenShift environment Network Policy
  class NetworkPolicy < ProjectResource
    RESOURCE = 'networkpolicies'
  end
end
