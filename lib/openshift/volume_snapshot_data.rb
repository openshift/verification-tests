module BushSlicer
  class VolumeSnapshotData < ClusterResource
    RESOURCE = "volumesnapshotdata"

    # @return [BushSlicer::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached volume snapshot data #{name} readiness",
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
  end
end
