module BushSlicer
  class PackageManifest < ClusterResource
    RESOURCE = "packagemanifests"

    def catalog_source(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'catalogSource')
    end

    def catalog_source_namespace(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'catalogSourceNamespace')
    end

    # @return Array of channels
    def channels(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'channels')
    end

    def default_channel(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'defaultChannel')
    end

    def provider(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'provider')
    end

  end
end
