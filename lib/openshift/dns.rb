module BushSlicer
  class Dns < ClusterResource
    RESOURCE = "dns"

    # Avoid API name in class name for dis particular class
    @kind = "DNS"

    def public_zone(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('spec', 'publicZone', 'id')
    end
  end
end  
