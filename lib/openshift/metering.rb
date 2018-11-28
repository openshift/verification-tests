require 'openshift/cluster_resource'

module BushSlicer
  # represents Metering CRD
  class Metering < ProjectResource
    RESOURCE = 'metering'
  end
end
