module BushSlicer
  class Infrastructure < ClusterResource
    RESOURCE = "infrastructures.config.openshift.io"

    # Avoid API name in class name for dis particular class
    @kind = "Infrastructure"

    def api_server_url(user: nil, cached: true, quiet: false)
      status_raw(user: user, cached: cached, quiet: quiet).dig("apiServerURL")
    end
    
    def infra_name(user: nil, cached: true, quiet: false)
      status_raw(user: user, cached: cached, quiet: quiet).dig("infrastructureName")
    end

    def platform(user: nil, cached: true, quiet: false)
      status_raw(user: user, cached: cached, quiet: quiet).dig("platform")
    end

    def infra_topology(user: nil, cached: true, quiet: false)
      status_raw(user: user, cached: cached, quiet: quiet).dig("infrastructureTopology")
    end

  end
end
