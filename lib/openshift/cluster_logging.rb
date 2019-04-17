# represent a clusterlogging object
module BushSlicer
  class ClusterLogging < ClusterResource
    RESOURCE = "clusterloggings"

    ### represent status section ["collection", "curation", "logStore", "message", "visualization"]
    def collection(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'collection')
    end
    def curation(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'curation')
    end

    def log_store(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'logStore')
    end

    def message(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'message')
    end

    def visualization(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'visualization')
    end


    def fluentd_status(user: nil, cached: true, quiet: false)
      self.collection(user: user, cached: cached, quiet: quiet).dig('logs', 'fluentdStatus')
    end

    def curator_status(user: nil, cached: true, quiet: false)
      self.curation(user: user, cached: cached, quiet: quiet)['curatorStatus']
    end

    def fluentd_pods(user: nil, cached: true, quiet: false)
      self.fluentd_status(user: user, cached: cached, quiet: quiet)['pods']
    end

    def fluentd_ready_pods(user: nil, cached: true, quiet: false)
      self.fluentd_pods(user: user, cached: cached, quiet: quiet)['ready']
    end

    def fluentd_failed_pods(user: nil, cached: true, quiet: false)
      self.fluentd_pods(user: user, cached: cached, quiet: quiet)['failed']
    end

    def fluentd_notready_pods(user: nil, cached: true, quiet: false)
      self.fluentd_pods(user: user, cached: cached, quiet: quiet)['notReady']
    end

    def es_status(user: nil, cached: true, quiet: false)
      self.log_store(user: user, cached: cached, quiet: quiet)['elasticsearchStatus']
    end

    def es_cluster_health(user: nil, cached: true, quiet: false)
      self.es_status(user: user, cached: cached, quiet: quiet).first['clusterHealth']
    end

    def es_pods(user: nil, cached: true, quiet: false)
      self.es_status(user: user, cached: cached, quiet: quiet).first['pods']
    end

    def kibana_status(user: nil, cached: true, quiet: false)
      self.visualization(user: user, cached: cached, quiet: quiet)['kibanaStatus']
    end

    def kibana_pods(user: nil, cached: true, quiet: false)
      self.kibana_status(user: user, cached: cached, quiet: quiet).first['pods']
    end

    # higher level methods
    def fluentd_ready?(user: nil, cached: true, quiet: false)
      fluentd_nodes = self.fluentd_status(user: user, cached: cached, quiet: quiet)['nodes'].keys.sort
      fluentd_nodes == self.fluentd_ready_pods && fluentd_failed_pods.count == 0 && fluentd_notready_pods.count == 0
    end

    def wait_until_fluentd_is_ready(user: nil, quiet: false, timeout: 5*60)
      wait_for(timeout) {
        fluentd_ready?(user: user, cached: false, quiet: quiet)
      }
    end
    # es is considered to be ready when clusterhealthy is gree
    def es_ready?(user: nil, cached: true, quiet: false)
      self.es_cluster_health(user: user, cached: cached, quiet: quiet) == 'green'
    end

    def wait_until_es_is_ready(user: nil, quiet: false, timeout: 10*60)
      wait_for(timeout) {
        es_ready?(user: user, cached: false, quiet: quiet)
      }
    end

    def kibana_ready?(user: nil, cached: true, quiet: false)
      failed_pods = self.kibana_pods(user: user, cached: cached, quiet: quiet)['failed']
      notready_pods = self.kibana_pods(user: user, cached: cached, quiet: quiet)['notReady']
      ready_pods = self.kibana_pods(user: user, cached: cached, quiet: quiet)['ready']
      replicas = self.kibana_status(user: user, cached: cached, quiet: quiet).first['replicas']
      replicas == ready_pods.count && failed_pods.count == 0 && notready_pods.count == 0
    end

    def wait_until_kibana_is_ready(user: nil, quiet: false, timeout: 10*60)
      wait_for(timeout) {
        kibana_ready?(user: user, cached: false, quiet: quiet)
      }
    end
  end
end
