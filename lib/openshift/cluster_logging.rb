# represent a clusterlogging object
require 'openshift/project_resource'

module BushSlicer
  class ClusterLogging < ProjectResource
    RESOURCE = "clusterloggings"

    ### represent status section ["collection", "curation", "logStore", "message", "visualization"]
    private def collection_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'collection')
    end
    private def curation_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'curation')
    end

    private def log_store_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'logStore')
    end

    private def message_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'message')
    end

    private def visualization_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'visualization')
    end

    private def collection_status_raw(user: nil, cached: true, quiet: false)
      collection_raw(user: user, cached: cached, quiet: quiet)['logs']
    end

    private def fluentd_status_raw(user: nil, cached: true, quiet: false)
      collection_status_raw(user: user, cached: cached, quiet: quiet)['fluentdStatus']
    end

    private def curator_status_raw(user: nil, cached: true, quiet: false)
      self.curation(user: user, cached: cached, quiet: quiet)['curatorStatus']
    end

    private def fluentd_pods(user: nil, cached: true, quiet: false)
      fluentd_status_raw(user: user, cached: cached, quiet: quiet)['pods']
    end

    private def fluentd_ready_pod_names(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['ready']
    end

    def fluentd_ready_pods(user: nil, cached: true, quiet: false)
      fluentd_ready_pod_names(user: user, cached: cached, quiet: quiet).map { |name|
        Pod.new(name: name, project: project).tap{ |p| p.default_user = default_user(user) }
      }
    end

    private def fluentd_failed_pod_names(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['failed']
    end

    private def fluentd_notready_pod_names(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['notReady']
    end

    private def es_status_raw(user: nil, cached: true, quiet: false)
      log_store_raw(user: user, cached: cached, quiet: quiet)['elasticsearchStatus']
    end

    def es_cluster_health(user: nil, cached: true, quiet: false)
      return es_status_raw(user: user, cached: cached, quiet: quiet).first['clusterHealth'] ||
        es_status_raw(user: user, cached: true, quiet: quiet).first['cluster']['status']
    end

    private def es_pods(user: nil, cached: true, quiet: false)
      es_status_raw(user: user, cached: cached, quiet: quiet).first['pods']
    end

    private def kibana_status(user: nil, cached: true, quiet: false)
      visualization_raw(user: user, cached: cached, quiet: quiet)['kibanaStatus']
    end

    private def kibana_pods(user: nil, cached: true, quiet: false)
      kibana_status(user: user, cached: cached, quiet: quiet).first['pods']
    end

    def fluentd_ready?(user: nil, cached: true, quiet: false)
      fluentd_nodes = fluentd_status_raw(user: user, cached: cached, quiet: quiet)['nodes'].keys.sort
      fluentd_nodes == fluentd_ready_pod_names.sort && fluentd_failed_pod_names.count == 0 && fluentd_notready_pod_names.count == 0
    end

    def wait_until_fluentd_is_ready(user: nil, quiet: false, timeout: 5*60)
      success = wait_for(timeout) {
        fluentd_ready?(user: user, cached: false, quiet: quiet)
      }
      unless success
        raise "fluentd did not become ready within #{timeout} seconds"
      end
    end
    # es is considered to be ready when clusterhealthy is gree
    def es_ready?(user: nil, cached: true, quiet: false)
      es_cluster_health(user: user, cached: cached, quiet: quiet) == 'green'
    end

    def wait_until_es_is_ready(user: nil, quiet: true, timeout: 10*60)
      success = wait_for(timeout) {
        log_store_raw(user: user, cached: false, quiet: quiet ) && es_ready?(user: user, cached: false, quiet: quiet)
      }
      unless success
        raise "elasticsearch cluster did not in green status within #{timeout} seconds"
      end
    end

    def kibana_ready?(user: nil, cached: true, quiet: false)
      failed_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['failed']
      notready_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['notReady']
      ready_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['ready']
      replicas = kibana_status(user: user, cached: cached, quiet: quiet).first['replicas']
      replicas == ready_pods.count && failed_pods.count == 0 && notready_pods.count == 0
    end

    def wait_until_kibana_is_ready(user: nil, quiet: false, timeout: 10*60)
      success = wait_for(timeout) {
        kibana_ready?(user: user, cached: false, quiet: quiet)
      }
      unless success
        raise "kibana did not become ready within #{timeout} seconds"
      end
    end

    def collection_spec(user: nil, quiet: false, cached: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'collection')
    end

    def log_store_spec(user: nil, quiet: false, cached: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'logStore')
    end

    def curation_spec(user: nil, quiet: false, cached: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'curation')
    end

    def visualization_spec(user: nil, quiet: false, cached: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'visualization')
    end

    def collection_type(user: nil, quiet: false, cached: true)
      return collection_spec(user: user, cached: cached, quiet: quiet).dig('logs', 'type')
    end

    def management_state(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'managementState')
    end

    def redundancy_policy(user: nil, quiet: false, cached: false)
      return log_store_spec(user: user, cached: cached, quiet: quiet).dig('elasticsearch', 'redundancyPolicy')
    end

    def logstore_storage(user: nil, quiet: false, cached: false)
      return log_store_spec(user: user, cached: cached, quiet: quiet).dig('elasticsearch', 'storage')
    end

    def logstore_storage_class_name(user: nil, cached: false, quiet: false)
      return logstore_storage(user: user, cached: cached, quiet: quiet).dig('storageClassName')
    end

    def logstore_storage_size(user: nil, cached: false, quiet: false)
      return logstore_storage(user: user, cached: cached, quiet: quiet).dig('size')
    end

    def logstore_node_count(user: nil, cached: false, quiet: false)
      return log_store_spec(user: user, cached: cached, quiet: quiet).dig('elasticsearch', 'nodeCount')
    end

    def retention_policy(user: nil, cached: true, quiet: true)
      return log_store_spec(user: user, cached: cached, quiet: quiet).dig('retentionPolicy')
    end

    def application_max_age(user: nil, cached: true, quiet: true)
      return retention_policy(user: user, cached: cached, quiet: quiet).dig('application', 'maxAge')
    end

    def audit_max_age(user: nil, cached: true, quiet: true)
      return retention_policy(user: user, cached: cached, quiet: quiet).dig('audit', 'maxAge')
    end

    def infra_max_age(user: nil, cached: true, quiet: true)
      return retention_policy(user: user, cached: cached, quiet: quiet).dig('infra', 'maxAge')
    end

    def curation_schedule(user: nil, cached: false, quiet: true)
      return curation_spec(user: user, cached: cached, quiet: quiet).dig('curator', 'schedule')
    end

    def es_node_conditions(user: nil, cached: false, quiet: true)
      return es_status_raw(user: user, cached: cached, quiet: quiet).first['nodeConditions']
    end

    def es_cluster_conditions(user: nil, cached: false, quiet: true)
      return es_status_raw(user: user, cached: cached, quiet: quiet).first['clusterConditions']
    end

    def kibana_cluster_condition(user: nil, cached: false, quiet: true)
      return kibana_status(user: user, cached: cached, quiet: quiet).first['clusterCondition']
    end

    def fluentd_cluster_condition(user: nil, cached: false, quiet: true)
      return fluentd_status_raw(user: user, cached: cached, quiet: quiet).dig('clusterCondition')
    end

  end
end
