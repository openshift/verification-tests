require 'openshift/project_resource'

module BushSlicer
  class VolumeSnapshot < ProjectResource
    RESOURCE = "volumesnapshots"

    def snapshot_data_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'snapshotDataName')
    end

    # @return [BushSlicer::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached volume snapshot #{name} readiness",
                response: props[:raw].to_yaml,
                success: true,
                exitstatus: 0,
                parsed: props[:raw]
        }
      else
        res = get(user: user, quiet: quiet)
      end
      if res[:success]
        res[:success] =
          res[:parsed]["status"] &&
          res[:parsed]["status"]["conditions"] &&
          res[:parsed]["status"]["conditions"].any? { |c|
            c["type"] == "Ready" && c["status"] == "True"
          }
      end

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
