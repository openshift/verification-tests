@clusterlogging
Feature: elasticsearch-operator related tests

  # @author qitang@redhat.com
  # @case_id OCP-21332
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for Elasticsearch is deployed along with the Elasticsearch cluster
    Given I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").port == "elasticsearch"
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").path == "/_prometheus/metrics"
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?          |
      | query | es_cluster_nodes_number |
    Then the step should succeed
    And the expression should be true>  @result[:parsed]['data']['result'][0]['value']
    """

  # @author qitang@redhat.com
  # @case_id OCP-21530
  @admin
  @destructive
  Scenario: elasticsearch alerting rules test: ElasticsearchClusterNotHealthy
    Given I create clusterlogging instance with:
      | remove_logging_pods | true                                                                 |
      | crd_yaml            | <%= BushSlicer::HOME %>/testdata/logging/clusterlogging/example.yaml |
    Then the step should succeed
    Given I wait for the "elasticsearch-prometheus-rules" prometheus_rule to appear
    And I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
    
    Given a pod becomes ready with labels:
      | es-node-master=true |
    And I execute on the pod:
      | es_util                                                        |
      | --query=_cluster/settings                                      |
      | -XPUT                                                          |
      | -d                                                             |
      | {"transient" : {"cluster.routing.allocation.enable" : "none"}} |
    Then the step should succeed
    And the output should contain:
      | "acknowledged":true |
    When I execute on the pod:
      | es_util               |
      | --query=.operations.* |
      | -XDELETE              |
    Then the step should succeed
    And the output should contain:
      | "acknowledged":true |

    And I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                                     |
      | query | ALERTS{alertname="ElasticsearchClusterNotHealthy"} |
    Then the step should succeed
    And the output should match:
      | "alertstate":"pending\|firing" |
    """
