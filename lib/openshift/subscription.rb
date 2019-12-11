module BushSlicer
  class Subscription < ProjectResource
    RESOURCE = "subscriptions"

    def current_csv(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'currentCSV')
    end

  end
end
