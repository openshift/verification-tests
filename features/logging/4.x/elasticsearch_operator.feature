@clusterlogging
Feature: elasticsearch-operator related tests

  # @auther qitang@redhat.com
  # @case_id OCP-21313
  @admin
  @destructive
  @commonlogging
  Scenario: The default index.mode is shared_ops
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Then I wait for the "elasticsearch" configmap to appear
    Given I get project configmap named "elasticsearch" as YAML
    Then the step should succeed
    And the output should contain:
      | openshift.kibana.index.mode: shared_ops |

  # @author qitang@redhat.com
  # @case_id OCP-21332
  # @case_id OCP-21487
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for Elasticsearch is deployed along with the Elasticsearch cluster
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-monitoring" project
    And I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name | prometheus-k8s |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :token clipboard

    Given I use the "openshift-logging" project
    When I get project servicemonitor named "monitor-elasticsearch-cluster" as YAML
    Then the step should succeed
    And the output should contain:
      | port: elasticsearch        |
      | path: /_prometheus/metrics |
    When I get project service named "elasticsearch-metrics" as YAML
    Then the step should succeed
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | elasticsearch        |
      | service_ip | <%= cb.service_ip %> |
      | token      | <%= cb.token %>      |
    Then the step should succeed
    And the output should contain:
      | es_cluster_nodes_number                   |
      | es_cluster_shards_active_percent          |


  # @author qitang@redhat.com
  # @case_id OCP-21099
  @admin
  @destructive
  @commonlogging
  Scenario: Access Elasticsearch prometheus Endpoints via token
    Given I switch to the first user
    Given cluster role "cluster-admin" is added to the "first" user
    And evaluation of `user.cached_tokens.first` is stored in the :user_token clipboard

    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    When I get project service named "elasticsearch-metrics" as YAML
    Then the step should succeed
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | elasticsearch        |
      | service_ip | <%= cb.service_ip %> |
      | token      | <%= cb.user_token %> |
    Then the step should succeed
    And the output should contain:
      | es_cluster_nodes_number                   |
      | es_cluster_shards_active_percent          |

