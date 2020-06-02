require 'openshift/project_resource'

module BushSlicer
  class Kibana < ProjectResource
    RESOURCE = "kibanas"

    def management_state(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'managementState')
    end

    def node_selector(user: nil, quiet: true, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'nodeSelector')
    end

    def status(user: nil, quiet: true, cached: false)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('status')
    end

    def spec_replicas(user: nil, quiet: true, cached: false)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'replicas')
    end

  end
end
