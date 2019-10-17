@clusterlogging
Feature: collector related tests

  # @auther qitang@redhat.com
  # case_id OCP-25365
  @admin @destructive
  @commonlogging
  Scenario: The System Journald log can be collected
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    And I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Then the step should succeed
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | .operation*/_search?pretty'  -d '{"query": {"exists": {"field": "systemd"}}} |
      | op           | GET                                                                          |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['name'] == cb.collection_type
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['inputname'] == (cb.collection_type == "fluentd" ? "fluent-plugin-systemd" : "imfile")

  # @auther qitang@redhat.com
  # @case_id OCP-18147
  @admin @destructive
  @commonlogging
  Scenario: The Container logs metadata check
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/loggen/container_json_unicode_log_template.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given evaluation of `pod` is stored in the :log_pod clipboard
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    And I wait for the "project.<%= cb.proj.name %>" index to appear in the ES pod with labels "es-node-master=true"
    Then the step should succeed
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | project.<%= cb.proj.name %>.*/_search?pretty |
      | op           | GET                                          |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['message'] == "ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦㄆ 中国 883.317µs ā á ǎ à ō ó ▅ ▆ ▇ █ 々"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['name'] == cb.collection_type
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['inputname'] == (cb.collection_type == "fluentd" ? "fluent-plugin-systemd" : "imfile")
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['pipeline_metadata']['collector']['ipaddr4'] == cb.log_pod.node_ip
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['docker']['container_id'] == cb.log_pod.container(user: user, name: 'centos-logtest').id
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['container_name'] == "centos-logtest"
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['namespace_name'] == cb.proj.name
    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['kubernetes']['pod_name'] == cb.log_pod.name
