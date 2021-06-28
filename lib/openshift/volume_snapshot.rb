require 'openshift/project_resource'

module BushSlicer
  class VolumeSnapshot < ProjectResource
    RESOURCE = "volumesnapshots"

    def snapshot_data_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'snapshotDataName')
    end

    def ready?(user:, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'readyToUse') == true
    end

    def wait_till_ready(user: nil, seconds: 30)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = ready?(user: user, quiet: true)
        iterations = iterations + 1
      }
      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
                    "seconds:\n"

      return res
    end

    def pvc_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'source', 'persistentVolumeClaimName')
    end

    def volume_snapshot_class_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'volumeSnapshotClassName')
    end

    def restore_size(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      size = rr.dig('status', 'restoreSize')
      if size
        size = size.scan(/\d+/)[0].to_s
      end
      return size
    end

    def volume_snapshot_content_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'boundVolumeSnapshotContentName')
    end

  end
end
