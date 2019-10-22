@clusterlogging
Feature: cluster-logging-operator related test

  # @author qitang@redhat.com
  # @case_id OCP-21333
  # @case_id OCP-19875
  # @case_id OCP-24111
  # @case_id OCP-24578
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for collector is deployed along with cluster logging
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-monitoring" project
    And I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name | prometheus-k8s |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :token clipboard
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    When I get project servicemonitor named "<%= cb.collection_type %>" as YAML
    Then the step should succeed
    And the output should contain:
      | port: metrics  |
      | path: /metrics |
    When I get project service named "<%= cb.collection_type %>" as YAML
    Then the step should succeed
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | <%= cb.collection_type %> |
      | service_ip | <%= cb.service_ip %>      |
      | token      | <%= cb.token %>           |
    Then the step should succeed
    And the expression should be true> @result[:response].include? (cb.collection_type == "fluentd" ? "fluentd_output_status_buffer_total_bytes": "rsyslog_action_processed")
