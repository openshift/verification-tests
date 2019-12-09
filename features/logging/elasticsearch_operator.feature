@clusterlogging
Feature: elasticsearch-operator related tests

  # @author qitang@redhat.com
  # @case_id OCP-21332
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for Elasticsearch is deployed along with the Elasticsearch cluster
    Given I use the "openshift-monitoring" project
    And I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name | prometheus-k8s |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :token clipboard

    Given I use the "openshift-logging" project
    Given the expression should be true> service_monitor("monitor-elasticsearch-cluster").port == "elasticsearch"
    And the expression should be true> service_monitor("monitor-elasticsearch-cluster").path == "/_prometheus/metrics"
    Given evaluation of `service("elasticsearch-metrics").ip` is stored in the :service_ip clipboard

    Given I run curl command on the ES pod to get metrics with:
      | object     | elasticsearch        |
      | service_ip | <%= cb.service_ip %> |
      | token      | <%= cb.token %>      |
    Then the step should succeed
    And the output should contain:
      | es_cluster_nodes_number                   |
      | es_cluster_shards_active_percent          |
