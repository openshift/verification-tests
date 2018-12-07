require 'openshift/cluster_resource'

module VerificationTests
  # represents Metering CRD
  class Metering < ProjectResource
    RESOURCE = 'metering'
  end
end
