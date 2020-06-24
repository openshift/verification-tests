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

    def index_management(user: nil, quiet: false, cached: true)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'indexManagement')
    end

    def index_management_mappings(user: nil, quiet: false, cached: true)
      return index_management(user: user, cached: cached, quiet: quiet).dig('mappings')
    end

    def mapping(user: nil, name:, quiet: false, cached: true)
      mapping = nil
      mappings = self.index_management_mappings(user: user, cached: cached, quiet: quiet)
      mappings.each do | m |
        mapping = m if m['name'] == name
      end
      return mapping
    end

    def policy_ref(user: nil, name:, quiet: false, cached: true)
      return mapping(user: user, name: name, quiet: quiet, cached: cached).dig('policyRef')
    end

    def index_management_policies(user: nil, quiet: false, cached: true)
      return index_management(user: user, cached: cached, quiet: quiet).dig('policies')
    end

    def policy(user: nil, name:, quiet: false, cached: true)
      policy = nil
      policies = self.index_management_policies(user: user, cached: cached, quiet: quiet)
      policies.each do | p |
        policy = p if p['name'] == name
      end
      return policy
    end

    def delete_min_age(user: nil, name:, quiet: false, cached: true)
      return policy(user: user, name: name, quiet: quiet, cached: cached).dig('phases', 'delete', 'minAge')
    end

    def rollover_max_age(user: nil, name:, quiet: false, cached: true)
      return policy(user: user, name: name, quiet: quiet, cached: cached).dig('phases', 'hot', 'actions', 'rollover', 'maxAge')
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

    def status(user: nil, quiet: true, cached: false)
      return raw_resource(user: user, cached: cached, quiet: quiet).dig('status')
    end

    def cluster_status(user: nil, quiet: false, cached: false)
      return status.dig('cluster')
    end

    def cluster_health(user: nil, cached: false, quiet: false)
      return cluster_status(user: user, cached: true, quiet: quiet).dig('status') || 
        status(user: user, cached: cached, quiet: quiet).dig('clusterHealth')   
    end

    def active_primary_shards(user: nil, cached: false, quiet: false)
      return cluster_status.dig('activePrimaryShards')
    end

    def active_shards(user: nil, cached: false, quiet: false)
      return cluster_status.dig('activeShards')
    end

    def initializing_shards(user: nil, cached: false, quiet: false)
      return cluster_status.dig('initializingShards')
    end

    def num_data_nodes(user: nil, cached: false, quiet: false)
      return cluster_status.dig('numDataNodes')
    end

    def num_nodes(user: nil, cached: false, quiet: false)
      return cluster_status.dig('numNodes')
    end

    def relocating_shards(user: nil, cached: false, quiet: false)
      return cluster_status.dig('relocatingShards')
    end

    def unassigned_shards(user: nil, cached: false, quiet: false)
      return cluster_status.dig('unassignedShards')
    end

  end
end
