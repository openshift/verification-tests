module BushSlicer
  class ServiceBinding < ProjectResource
    RESOURCE = "servicebindings"
    
    def external_id(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'externalID')
    end

    # @return [BushSlicer::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached service instance #{name} readiness",
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