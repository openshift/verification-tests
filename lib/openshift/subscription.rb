module BushSlicer
  class Subscription < ProjectResource
    RESOURCE = "subscriptions.operators.coreos.com"

    def current_csv(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'currentCSV')
    end

    def startingCSV(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'currentCSV')      
    end

    def ready?(user:, quiet: false)
       res = get(user: user, quiet: quiet)
       if res[:success]
         res[:success] =
           res[:parsed]["status"]["state"] == "AtLatestKnown"
        end
        return res
    end

    def installplan_geneation(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'installPlanGeneration')
    end

    def installplan_ref(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'installPlanRef')
    end

    def installplan_csv(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'installedCSV')
    end

    def installplan(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'installplan')
    end

    def channel(user: nil, quiet: false, cached: true)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'channel')
    end

    def source(user: nil, quiet: false, cached: true)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'source')
    end

  end
end
