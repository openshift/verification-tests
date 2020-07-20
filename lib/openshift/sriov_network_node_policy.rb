require 'openshift/project_resource'

module BushSlicer
  class SriovNetworkNodePolicy < ProjectResource
    RESOURCE = "sriovnetworknodepolicies"
  end
end
