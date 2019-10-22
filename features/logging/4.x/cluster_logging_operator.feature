@clusterlogging
Feature: cluster-logging-operator related test

  # @auther qitang@redhat.com
  @admin @destructive
  Scenario Outline: ServiceMonitor object for collector is deployed along with cluster logging
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-monitoring" project
    And I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name | prometheus-k8s |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :token clipboard
    Given I use the "openshift-logging" project
    Given I create clusterlogging instance with:
      | remove_logging_pods | true            |
      | crd_yaml            | <crd_yaml>      |
      | log_collector       | <log_collector> |
    Then the step should succeed
    When I get project servicemonitor named "<log_collector>" as YAML
    Then the step should succeed
    And the output should contain:
      | port: metrics  |
      | path: /metrics |
    And evaluation of `service("<log_collector>").ip` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | <log_collector>      |
      | service_ip | <%= cb.service_ip %> |
      | token      | <%= cb.token %>      |
    Then the step should succeed
    And the expression should be true> @result[:response].include? "<metrics_name>"

    Examples:
      | crd_yaml                                                                                                              | log_collector | metrics_name                             |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml                | fluentd       | fluentd_output_status_buffer_total_bytes | # @case_id OCP-21333 # @case_id OCP-19875
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/customresource-rsyslog.yaml | rsyslog       | rsyslog_action_processed                 | # @case_id OCP-24111 # @case_id OCP-24578
