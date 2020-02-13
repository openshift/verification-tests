require 'openshift/project_resource'

module BushSlicer
  class Elasticsearch < ProjectResource
    RESOURCE = "elasticsearches"

    def management_state(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'managementState')
    end

    def redundancy_policy(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'redundancyPolicy')
    end

    def nodes(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'nodes')
    end

    def resources(user: nil, quiet: true, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'nodeSpec', 'resources')
    end

    def resource_limit_cpu(user: nil, quiet: true, cached: false)
      return resources(user: user, cached: cached, quiet: quiet).dig('limits', 'cpu')
    end

    def resource_limit_memory(user: nil, quiet: true, cached: false)
      return resources(user: user, cached: cached, quiet: quiet).dig('limits', 'memory')
    end

    def resource_request_cpu(user: nil, quiet: true, cached: false)
      return resources(user: user, cached: cached, quiet: quiet).dig('requests', 'cpu')
    end

    def resource_request_memory(user: nil, quiet: true, cached: false)
      return resources(user: user, cached: cached, quiet: quiet).dig('requests', 'memory')
    end

    def node_selector(user: nil, quiet: true, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'nodeSpec', 'nodeSelector')
    end

    def cluster_status(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'cluster')
    end

  end
end
