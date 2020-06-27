require 'openshift/cluster_resource'

module BushSlicer
  # represents Metering CRD
  class MeteringConfig < ProjectResource
    RESOURCE = 'meteringconfig'

    # return the hive storage type
    def hive_type(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'storage', 'hive', 'type')
    end

  end
end
