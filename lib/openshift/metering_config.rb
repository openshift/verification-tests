require 'openshift/cluster_resource'

module BushSlicer
  # represents Metering CRD
  class MeteringConfig < ProjectResource
    RESOURCE = 'meteringconfig'
  end
end
