module BushSlicer
  class Subscription < ProjectResource
    RESOURCE = "subscriptions"

    def current_csv(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'currentCSV')
    end

    def ready?(user:, quiet: false, cached: false)
       res = get(user: user, quiet: quiet)
       if res[:success]
         res[:success] =
           res[:parsed]["status"]["state"] == "AtLatestKnown"
        end
        return res
    end
  end
end
