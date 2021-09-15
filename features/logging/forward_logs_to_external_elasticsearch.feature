@clusterlogging
Feature: Cases to test forward logs to external elasticsearch

  # @author qitang@redhat.com
  @admin
  @destructive
  @gcp-upi
  @gcp-ipi
  Scenario Outline: ClusterLogForwarder: Forward logs to non-clusterlogging-managed elasticsearch
    Given I switch to the first user
    And I have a project
    And evaluation of `project` is stored in the :es_proj clipboard
    Given external elasticsearch server is deployed with:
      | version               | 6.8                     |
      | scheme                | <scheme>                |
      | transport_ssl_enabled | <transport_ssl_enabled> |
      | project_name          | <%= cb.es_proj.name %>  |
      | secret_name           | pipelinesecret          |

    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/elasticsearch/<file>"
    When I process and create:
      | f | <file> |
      | p | URL=<scheme>://elasticsearch-server.<%= cb.es_proj.name %>.svc:9200 |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed

    Given I use the "<%= cb.es_proj.name %>" project
    And I wait up to 300 seconds for the steps to pass:
    """
    # check app logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check journal logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check logs in openshift* namespace
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check audit logs
    When I execute on the "<%= cb.log_receiver.name %>" pod:
      | curl | -sk | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    """

    Examples:
      | scheme | transport_ssl_enabled | file                 |
      | https  | true                  | clf-with-secret.yaml | # @case_id OCP-29845
      | http   | false                 | clf-insecure.yaml    | # @case_id OCP-29846

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: Forward to external ES with username/password
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :es_proj clipboard
    Given external elasticsearch server is deployed with:
      | version               | <version>               |
      | scheme                | <scheme>                |
      | transport_ssl_enabled | <transport_ssl_enabled> |
      | user_auth_enabled     | true                    |
      | project_name          | <%= cb.es_proj %>       |
      | username              | <username>              |
      | password              | <password>              |
      | secret_name           | <secret_name>           |
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/elasticsearch/clf-with-secret.yaml"
    When I process and create:
      | f | clf-with-secret.yaml |
      | p | URL=<scheme>://elasticsearch-server.<%= cb.es_proj %>.svc:9200 |
      | p | PIPELINE_SECRET_NAME=<secret_name> |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed

    Given I use the "<%= cb.es_proj %>" project
    And a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 300 seconds for the steps to pass:
    """
    # check app logs
    When I execute on the pod:
      | curl | -sk | -u | <username>:<password> | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check journal logs
    When I execute on the pod:
      | curl | -sk | -u | <username>:<password> | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check logs in openshift* namespace
    When I execute on the pod:
      | curl | -sk | -u | <username>:<password> | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check audit logs
    When I execute on the pod:
      | curl | -sk | -u | <username>:<password> | -XGET | <scheme>://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    """

    Examples:
      | version | scheme | transport_ssl_enabled | username | password | secret_name |
      | 7.12    | https  | true                  | test1    | redhat   | test1       | #@case_id OCP-41807
      | 6.8     | http   | false                 | test2    | redhat   | test2       | #@case_id OCP-41805
      | 7.12    | http   | true                  | test3    | redhat   | test3       | #@case_id OCP-41808
      | 6.8     | https  | false                 | test4    | redhat   | test4       | #@case_id OCP-41806
