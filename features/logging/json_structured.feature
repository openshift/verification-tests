@clusterlogging
Feature: JSON structured logs

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: JSON structured indices
    Given I switch to the first user
    Given I create a project with non-leading digit name
    And evaluation of `project.name` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I obtain test data file "logging/clusterlogging/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/json_structured_indices/<CLF_yaml>"
    When I process and create:
      | f | <CLF_yaml>                  |
      | p | DATA_PROJECT=<%= cb.proj %> |   
    Then the step should succeed
    Given I wait up to 420 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cat/indices?format=JSON |
      | op           | GET                      |
    Then the step should succeed
    And the output should contain:
      | <indexName> |
    """
    And I wait for the project "<%= cb.proj %>" logs to appear in the ES pod
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | <indexName>*/_search?pretty' -d '{"size": 1, "sort": [{"@timestamp": {"order":"desc"}}], "query": {"match": {"kubernetes.namespace_name": "<%= cb.proj %>"}}} |
      | op           | GET |
    Then the step should succeed
    And the output should contain:
      | "structured" : {                           |
      |   "foo:bar" : "Colon Item"                 |
      |   "foo.bar" : "Dot Item"                   |
      |   "Number" : 10                            |
      |   "level" : "debug"                        |
      |   "{foobar}" : "Brace Item"                |
      |   "foo bar" : "Space Item"                 |
      |   "StringNumber" : "10"                    |
      |   "layer2" : {                             |
      |     "name" : "Layer2 1"                    |
      |     "tips" : "Decide by PRESERVE_JSON_LOG" |
      |   "message" : "MERGE_JSON_LOG=true"        |
      |   "Layer1" : "layer1 0"                    |
      |   "[foobar]" : "Bracket Item"              |
    """
 
    Examples:
      | CLF_yaml       | indexName              |
      | OCP_41847.yaml | app-centos-logtest     | # @case_id OCP-41847
      | OCP_41848.yaml | app-qa-openshift-label | # @case_id OCP-41848
      | OCP_42386.yaml | app-<%= cb.proj %>     | # @case_id OCP-42386
      | OCP_42475.yaml | app-centos-logtest     | # @case_id OCP-42475

  # @author qitang@redhat.com
  # @case_id OCP-41302
  @admin
  @destructive
  Scenario Outline: Forward JSON structured logs to external ES
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :es_proj clipboard
    Given external elasticsearch server is deployed with:
      | version               | 6.8               |
      | scheme                | https             |
      | transport_ssl_enabled | true              |
      | project_name          | <%= cb.es_proj %> |
      | secret_name           | pipelinesecret    |

    Given I create a project with non-leading digit name
    And evaluation of `project.name` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/json_structured_indices/<CLF_yaml>"
    When I process and create:
      | f | <CLF_yaml>                                                  |
      | p | DATA_PROJECT=<%= cb.proj %>                                 |
      | p | SECRET_NAME=pipelinesecret                                  |
      | p | URL=https://elasticsearch-server.<%= cb.es_proj %>.svc:9200 |
    Then the step should succeed
    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed
    Given I use the "<%= cb.es_proj %>" project
    And a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 420 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -sk | -XGET | https://localhost:9200/_cat/indices?format=JSON |
    Then the step should succeed
    And the output should contain:
      | <indexName> |
    """
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -sk | -XGET | https://localhost:9200/<indexName>*/_search?pretty | -H | Content-Type: application/json | -d | {"size": 2, "sort": [{"@timestamp": {"order":"desc"}}], "query": {"match": {"kubernetes.namespace_name": "<%= cb.proj %>"}}} |
    Then the step should succeed
    And the output should contain:
      | "structured" : {                           |
      |   "message" : "MERGE_JSON_LOG=true"        |
      |   "level" : "debug"                        |
      |   "Layer1" : "layer1 0"                    |
      |   "layer2" : {                             |
      |     "name" : "Layer2 1"                    |
      |     "tips" : "Decide by PRESERVE_JSON_LOG" |
      |   "StringNumber" : "10"                    |
      |   "Number" : 10                            |
      |   "foo.bar" : "Dot Item"                   |
      |   "{foobar}" : "Brace Item"                |
      |   "[foobar]" : "Bracket Item"              |
      |   "foo:bar" : "Colon Item"                 |
      |   "foo bar" : "Space Item"                 |
    """
    Examples:
      | CLF_yaml       | indexName              |
      | OCP_41300.yaml | app-qa-openshift-label | # @case_id OCP-41300
      | OCP_41729.yaml | app-qa-index-name      | # @case_id OCP-41729
      | OCP_41730.yaml | app-<%= cb.proj %>     | # @case_id OCP-41730/41302
      | OCP_41732.yaml | app-centos-logtest     | # @case_id OCP-41732
      | OCP_41787.yaml | app-fall-in-index      | # @case_id OCP-41787
      | OCP_41788.yaml | app-write              | # @case_id OCP-41788

  # @author qitang@redhat.com
  # @case_id OCP-41785
  @admin
  @destructive
  Scenario: No dynamically index when no type: json in output
    Given I switch to the first user
    Given I create a project with non-leading digit name
    And evaluation of `project.name` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I obtain test data file "logging/clusterlogging/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/json_structured_indices/OCP_41785.yaml"
    When I process and create:
      | f | OCP_41785.yaml              |
      | p | DATA_PROJECT=<%= cb.proj %> |
    Then the step should succeed
    And I wait for the project "<%= cb.proj %>" logs to appear in the ES pod
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cat/indices?format=JSON |
      | op           | GET                      |
    Then the step should succeed
    And the output should not contain:
      | app-<%= cb.proj %> |
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app-00*/_search?pretty' -d '{"size": 2, "sort": [{"@timestamp": {"order":"desc"}}], "query": {"match": {"kubernetes.namespace_name": "<%= cb.proj %>"}}} |
      | op           | GET |
    Then the step should succeed
    And the output should contain:
      | "message" : "{\"message\": \"MERGE_JSON_LOG=true\", \"level\": \"debug\",\"Layer1\": \"layer1 0\", \"layer2\": {\"name\":\"Layer2 1\", \"tips\":\"Decide by PRESERVE_JSON_LOG\"}, \"StringNumber\":\"10\", \"Number\": 10,\"foo.bar\":\"Dot Item\",\"{foobar}\":\"Brace Item\",\"[foobar]\":\"Bracket Item\", \"foo:bar\":\"Colon Item\",\"foo bar\":\"Space Item\" }" |
    And the output should not contain:
      | "structured" : {                           |
      |   "foo:bar" : "Colon Item"                 |
      |   "foo.bar" : "Dot Item"                   |
      |   "Number" : 10                            |
      |   "level" : "debug"                        |
      |   "{foobar}" : "Brace Item"                |
      |   "foo bar" : "Space Item"                 |
      |   "StringNumber" : "10"                    |
      |   "layer2" : {                             |
      |     "name" : "Layer2 1"                    |
      |     "tips" : "Decide by PRESERVE_JSON_LOG" |
      |   "message" : "MERGE_JSON_LOG=true"        |
      |   "Layer1" : "layer1 0"                    |
      |   "[foobar]" : "Bracket Item"              |
