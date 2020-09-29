@clusterlogging
Feature: cluster log forwarder features

  # @author qitang@redhat.com
  # @case_id OCP-25989
  @admin
  @destructive
  @commonlogging
  Scenario: ClusterLogForwarder `default` behavior testing
    Given the master version >= "4.6"
    # create project to generate logs
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    # check logs in ES
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | audit*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] = 0
    # forward logs to fluentd server
    Given fluentd receiver is deployed as secure in the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    Given I obtain test data file "logging/clusterlogforwarder/fluentd/secure/clusterlogforwarder.yaml"
    When I run the :create client command with:
      | f | clusterlogforwarder.yaml |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear
    Given 10 seconds have passed
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |
    Given I wait up to 300 seconds for the steps to pass:
    """
    And I execute on the "<%= cb.log_receiver.name %>" pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log             |
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    # the ES should not receive new logs(may have some cache in the fluentd)

    Given I wait up to 600 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?pretty  |
      | op           | GET                 |
    Then the step should succeed
    And evaluation of `@result[:parsed]['count']` is stored in the :app_log_count_1 clipboard
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And evaluation of `@result[:parsed]['count']` is stored in the :infra_log_count_1 clipboard
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | audit*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] = 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?pretty  |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] == cb.app_log_count_1
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] == cb.infra_log_count_1
    """
    
    # forward logs to fluentd and ES
    Given I obtain test data file "logging/clusterlogforwarder/multiple_receiver/clusterlogforwarder.yaml"
    When I run the :apply client command with:
      | f | clusterlogforwarder.yaml |
    Then the step should succeed
    Given 10 seconds have passed
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |

    Given I wait up to 300 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?pretty  |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > cb.app_log_count_1
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > cb.infra_log_count_1
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | audit*/_count?pretty  |
      | op           | GET                   |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    """
    When I run the :delete client command with:
      | object_type       | pod                         |
      | object_name_or_id | <%= cb.log_receiver.name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | logging-infra=fluentdserver |
    Given I wait up to 300 seconds for the steps to pass:
    """
    And I execute on the pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log             |
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    
  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: ClusterLogForwarder: Forward logs to fluentd
    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
      | check_status        | false             |
    Then the step should succeed
    Given I wait for the "fluentd" daemon_set to appear up to 300 seconds
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |
    Given fluentd receiver is deployed as <security> in the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/fluentd/<security>/clusterlogforwarder.yaml"
    When I run the :create client command with:
      | f | clusterlogforwarder.yaml |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |
    Given I wait up to 300 seconds for the steps to pass:
    """
    And I execute on the "<%= cb.log_receiver.name %>" pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log             |
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    Examples:
      | security |
      | insecure | # @case_id OCP-29843
      | secure   | # @case_id OCP-29844

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: ClusterLogForwarder: Forward logs to non-clusterlogging-managed elasticsearch
    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
      | check_status        | false             |
    Then the step should succeed
    Given I wait for the "fluentd" daemon_set to appear up to 300 seconds
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |
    
    Given elasticsearch receiver is deployed as <security> in the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/elasticsearch/<security>/clusterlogforwarder.yaml"
    When I run the :create client command with:
      | f | clusterlogforwarder.yaml |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    And <%= daemon_set('fluentd').replica_counters[:desired] %> pods become ready with labels:
      | logging-infra=fluentd |
    Given I wait up to 300 seconds for the steps to pass:
    """
    # check app logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <url>/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['count'] > 0

    # check journal logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <url>/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['count'] > 0

    # check logs in openshift* namespace
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <url>/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['count'] > 0

    # check audit logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <url>/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['count'] > 0
    """

    Examples:
      | security | url                    |
      | insecure | http://localhost:9200  | # @case_id OCP-29846
      | secure   | https://localhost:9200 | # @case_id OCP-29845

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: Forward logs with tags
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I obtain test data file "logging/clusterlogforwarder/<file>"
    And admin ensures "instance" cluster_log_forwarder is deleted after scenario
    When I run the :create client command with:
      | f | <file> |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear
    Given I obtain test data file "logging/clusterlogging/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    And I wait for the "audit" index to appear in the ES pod
    And I wait up to 300 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_search?format=JSON' -d '{"size": 2, "sort": [{"@timestamp": {"order":"desc"}}]} |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['hits']['hits'][0]['_source']['openshift']['labels'] == cluster_log_forwarder('instance').output_labels(name: '<app_pipeline_name>')
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_search?format=JSON' -d '{"size": 2, "sort": [{"@timestamp": {"order":"desc"}}], "query": {"exists": {"field": "systemd"}}} |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['hits']['hits'][0]['_source']['openshift']['labels'] == cluster_log_forwarder('instance').output_labels(name: '<infra_pipeline_name>')
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_search?format=JSON' -d '{"size": 2, "sort": [{"@timestamp": {"order":"desc"}}], "query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['hits']['hits'][0]['_source']['openshift']['labels'] == cluster_log_forwarder('instance').output_labels(name: '<infra_pipeline_name>')
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | audit*/_search?format=JSON' -d '{"size": 2, "sort": [{"@timestamp": {"order":"desc"}}]} |
      | op           | GET                 |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:response])['hits']['hits'][0]['_source']['openshift']['labels'] == cluster_log_forwarder('instance').output_labels(name: '<audit_pipeline_name>')    
    """

    Examples:
      | file                                 | app_pipeline_name     | infra_pipeline_name   | audit_pipeline_name   |
      | clf-forward-with-same-tag.yaml       | forward-to-default-es | forward-to-default-es | forward-to-default-es | # @case_id OCP-33750
      | clf-forward-with-different-tags.yaml | forward-app-logs      | forward-infra-logs    | forward-audit-logs    | # @case_id OCP-33893
