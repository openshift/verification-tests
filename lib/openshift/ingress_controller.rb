module BushSlicer
  class IngressController < ProjectResource
    RESOURCE = "ingresscontrollers"


    ### status related methods
    def available_replicas(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'availableReplicas')
    end

    def domain(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'domain')
    end

    def endpoint_publishing_strategy(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'endpointPublishingStrategy', 'type')
    end

    def selector(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'selector')
    end

  end
end
