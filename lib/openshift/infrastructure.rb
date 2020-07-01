module BushSlicer
  class Infrastructure < ClusterResource
    RESOURCE = "infrastructures.config.openshift.io"

    # Avoid API name in class name for dis particular class
    @kind = "Infrastructure"

    def platform(user: nil, cached: true, quiet: false)
      status_raw(user: user, cached: cached, quiet: quiet).dig("platform")
    end
  end
end
