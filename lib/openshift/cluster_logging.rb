# represent a clusterlogging object
module BushSlicer
  class ClusterLogging < ClusterResource
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

    private def rsyslog_status_raw(user: nil, cached: true, quiet: false)
      collection_status_raw(user: user, cached: cached, quiet: quiet)['rsyslogStatus']
    end

    private def fluentd_status_raw(user: nil, cached: true, quiet: false)
      collection_status_raw(user: user, cached: cached, quiet: quiet)['fluentdStatus']
    end

    private def curator_status_raw(user: nil, cached: true, quiet: false)
      self.curation(user: user, cached: cached, quiet: quiet)['curatorStatus']
    end

    private def rsyslog_pods(user: nil, cached: true, quiet: false)
      rsyslog_status_raw(user: user, cached: cached, quiet: quiet)['pods']
    end

    private def rsyslog_ready_pods(user: nil, cached: true, quiet: false)
      rsyslog_pods(user: user, cached: cached, quiet: quiet)['ready']
    end

    private def rsyslog_failed_pods(user: nil, cached: true, quiet: false)
      rsyslog_pods(user: user, cached: cached, quiet: quiet)['failed']
    end

    private def rsyslog_notready_pods(user: nil, cached: true, quiet: false)
      rsyslog_pods(user: user, cached: cached, quiet: quiet)['notReady']
    end

    private def fluentd_pods(user: nil, cached: true, quiet: false)
      fluentd_status_raw(user: user, cached: cached, quiet: quiet)['pods']
    end

    private def fluentd_ready_pods(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['ready']
    end

    private def fluentd_failed_pods(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['failed']
    end

    private def fluentd_notready_pods(user: nil, cached: true, quiet: false)
      fluentd_pods(user: user, cached: cached, quiet: quiet)['notReady']
    end

    private def es_status_raw(user: nil, cached: true, quiet: false)
      log_store_raw(user: user, cached: cached, quiet: quiet)['elasticsearchStatus']
    end

    private def es_cluster_health(user: nil, cached: true, quiet: false)
      @result = es_status_raw(user: user, cached: cached, quiet: quiet).first['clusterHealth']
      if @result
        es_status_raw(user: user, cached: cached, quiet: quiet).first['clusterHealth']
      else
        es_status_raw(user: user, cached: cached, quiet: quiet).first['cluster']['status']
      end
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

    # higher level methods
    def rsyslog_ready?(user: nil, cached: true, quiet: false)
      rsyslog_nodes = rsyslog_status_raw(user: user, cached: cached, quiet: quiet)['Nodes'].keys.sort
      rsyslog_nodes == rsyslog_ready_pods && rsyslog_failed_pods.count == 0 && rsyslog_notready_pods.count == 0
    end

    def fluentd_ready?(user: nil, cached: true, quiet: false)
      fluentd_nodes = fluentd_status_raw(user: user, cached: cached, quiet: quiet)['nodes'].keys.sort
      fluentd_nodes == fluentd_ready_pods && fluentd_failed_pods.count == 0 && fluentd_notready_pods.count == 0
    end

    def wait_until_rsyslog_is_ready(user: nil, quiet: false, timeout: 5*60)
      wait_for(timeout) {
        rsyslog_ready?(user: user, cached: false, quiet: quiet)
      }
    end

    def wait_until_fluentd_is_ready(user: nil, quiet: false, timeout: 5*60)
      wait_for(timeout) {
        fluentd_ready?(user: user, cached: false, quiet: quiet)
      }
    end
    # es is considered to be ready when clusterhealthy is gree
    def es_ready?(user: nil, cached: true, quiet: false)
      es_cluster_health(user: user, cached: cached, quiet: quiet) == 'green'
    end

    def wait_until_es_is_ready(user: nil, quiet: false, timeout: 10*60)
      wait_for(timeout) {
        es_ready?(user: user, cached: false, quiet: quiet)
      }
    end

    def kibana_ready?(user: nil, cached: true, quiet: false)
      failed_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['failed']
      notready_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['notReady']
      ready_pods = kibana_pods(user: user, cached: cached, quiet: quiet)['ready']
      replicas = kibana_status(user: user, cached: cached, quiet: quiet).first['replicas']
      replicas == ready_pods.count && failed_pods.count == 0 && notready_pods.count == 0
    end

    def wait_until_kibana_is_ready(user: nil, quiet: false, timeout: 10*60)
      wait_for(timeout) {
        kibana_ready?(user: user, cached: false, quiet: quiet)
      }
    end
  end
end
