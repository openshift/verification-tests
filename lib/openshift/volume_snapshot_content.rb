require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Storage Class
  class VolumeSnapshotContent < ClusterResource
    RESOURCE = "volumesnapshotcontents"

    def deletion_policy(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'deletionPolicy')
    end

    def driver(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'driver')
    end

    def volume_snapshot(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'volumeSnapshotRef', 'name')
    end

    def volume_snapshot_class(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'volumeSnapshotClassName')
    end

    def snapshot_handle(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'source', 'snapshotHandle')
    end

  end
end
