@clusterlogging
Feature: cluster-logging-operator related test

  # @auther qitang@redhat.com
  # @case_id OCP-21907
  # @case_id OCP-21288
  @admin
  @destructive
  Scenario: Deploy elasticsearch-operator via OLM using CLI
    Given logging operators are installed successfully

  # @auther qitang@redhat.com
  # @case_id OCP-21929
  @admin
  @destructive
  Scenario: SingleRedundancy
    Given I switch to cluster admin pseudo user
    And I create clusterlogging instance with:
      | remove_logging_pods | true                                                                                                             |
      | crd_yaml            | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/singleredundancy.yaml  |
      | log_collector       | fluentd                                                                                                          |
    Then the step should succeed
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | redundancyPolicy: SingleRedundancy |
    Given I get project elasticsearch named "elasticsearch" as YAML
    Then the step should succeed
    And the output should contain:
      | redundancyPolicy: SingleRedundancy |
    Given I get project configmap named "elasticsearch" as YAML
    Then the step should succeed
    And the output should contain:
      | PRIMARY_SHARDS=3 |
      | REPLICA_SHARDS=1 |
    Given I get the ".operations" logging index information from a pod with labels "es-node-master=true"
    And the expression should be true> cb.index_data['pri'] == "3" and cb.index_data['rep'] == "1" and cb.index_data['docs.count'] > "0"
    And the expression should be true> cb.op_index_regex = /.operations.(\d{4}).(\d{2}).(\d{2})/

  # @auther qitang@redhat.com
  # @case_id OCP-20242
  @admin
  @destructive
  Scenario: [intservice] [bz1399761] Logging fluentD daemon set should set quota for the pods
    Given I switch to cluster admin pseudo user
    And I create clusterlogging instance with:
      | remove_logging_pods | true                                                                                                   |
      | crd_yaml            | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example.yaml |
      | log_collector       | fluentd                                                                                                |
    Then the step should succeed
    Given I get project daemonset named "fluentd" as YAML
    Then the step should succeed
    And the output should contain:
      | resources:        |
      |   limits:         |
      |     memory: 736Mi |
      |   requests:       |
      |     cpu: 100m     |
      |     memory: 736Mi |

  # @auther qitang@redhat.com
  # @case_id OCP-21923
  @admin
  @destructive
  @commonlogging
  Scenario: The default value of managementState
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | managementState: Managed |
    Given I get project elasticsearch named "elasticsearch" as YAML
    Then the step should succeed
    And the output should contain:
      | managementState: Managed |

  # @author qitang@redhat.com
  # @case_id OCP-21333
  # @case_id OCP-19875
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for fluentd is deployed along with cluster logging
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-monitoring" project
    And I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name | prometheus-k8s |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :token clipboard
    Given I use the "openshift-logging" project
    When I get project servicemonitor named "fluentd" as YAML
    Then the step should succeed
    And the output should contain:
      | port: metrics  |
      | path: /metrics |
    When I get project service named "fluentd" as YAML
    Then the step should succeed
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard

    Given I run curl command on the CLO pod to get metrics with:
      | object     | fluentd              |
      | service_ip | <%= cb.service_ip %> |
      | token      | <%= cb.token %>      |
    Then the step should succeed
    And the output should contain:
      | fluentd_status_buffer_queue_length |
      | fluentd_output_status_retry_wait   |

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
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | nodeCount: 2 |
    Given 2 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":3}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | nodeCount: 3 |
    And I wait up to 600 seconds for the steps to pass:
    """
    And 3 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    """
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":4}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | nodeCount: 4 |
    And I wait up to 600 seconds for the steps to pass:
    """
    And 4 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true |
    And 3 pods become ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=true |
    And a pod becomes ready with labels:
      | cluster-name=elasticsearch,component=elasticsearch,es-node-client=true,es-node-data=true,es-node-master=false |
    """
