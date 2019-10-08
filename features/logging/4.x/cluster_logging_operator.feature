@clusterlogging
Feature: cluster-logging-operator related test

  # @author qitang@redhat.com
  # @case_id OCP-19875
  @admin
  @destructive
  @commonlogging
  Scenario: Fluentd provide Prometheus metrics
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    Given a pod becomes ready with labels:
      | component=<%= cb.collection_type %> |
    And I execute on the pod:
      | bash                                    |
      | -c                                      |
      | curl -k https://localhost:24231/metrics |
    Then the step should succeed
    And the expression should be true> @result[:response].include? (cb.collection_type == "fluentd" ? "fluentd_output_status_buffer_total_bytes": "rsyslog_action_processed")

  # @author qitang@redhat.com
  # @case_id OCP-21333
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
    And evaluation of `service('<%= cb.collection_type %>').ip` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | <%= cb.collection_type %> |
      | service_ip | <%= cb.service_ip %>      |
      | token      | <%= cb.token %>           |
    Then the step should succeed
    And the expression should be true> @result[:response].include? (cb.collection_type == "fluentd" ? "fluentd_output_status_buffer_total_bytes": "rsyslog_action_processed")

  # @auther qitang@redhat.com
  # @case_id OCP-21907
  @admin
  @destructive
  Scenario: Deploy elasticsearch-operator via OLM using CLI
    Given logging operators are installed successfully

  # @auther qitang@redhat.com
  # @case_id OCP-22492
  @admin @destructive
  Scenario: Scale Elasticsearch nodes by nodeCount 2->3->4 in clusterlogging
    Given I switch to cluster admin pseudo user
    And I create clusterlogging instance with:
      | remove_logging_pods | true                                                                                                     |
      | crd_yaml            | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/scalebase.yaml |
      | log_collector       | fluentd                                                                                                  |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_nodecount == 2
    Given 2 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":3}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_nodecount == 3
    And 3 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":4}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_nodecount == 4
    And 4 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true |
    And 3 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    And a pod becomes ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=false |
