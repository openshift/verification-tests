module BushSlicer
  class ServiceMonitor < ProjectResource
    RESOURCE = "servicemonitors"

    private def endpoints(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'endpoints')
    end

    def port(user: nil, quiet: false, cached: true)
      return endpoints(user: user, cached: cached, quiet: quiet).first['port']
    end

    def path(user: nil, quiet: false, cached: true)
      return endpoints(user: user, cached: cached, quiet: quiet).first['path']
    end

  end
end
