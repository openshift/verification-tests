require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Storage Class
  class VolumeSnapshotClass < ClusterResource
    RESOURCE = "volumesnapshotclasses"

    def deletion_policy(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('deletionPolicy')
    end

    def driver(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('driver')
    end
  end
end
