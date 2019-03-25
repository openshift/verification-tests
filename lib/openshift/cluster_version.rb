module BushSlicer
  class ClusterVersion < ClusterResource
    RESOURCE = "clusterversions"
    def channel(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'channel')
    end

    def upstream(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'upstream')
    end

    def version(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'desired', 'version')
    end
  end
end
