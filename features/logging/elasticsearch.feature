@clusterlogging
Feature: Elasticsearch related tests

  # @author qitang@redhat.com
  # @case_id OCP-21487
  @admin
  @destructive
  @commonlogging
  Scenario: Elasticsearch Prometheus metrics can be accessed.
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _prometheus/metrics |
      | op           | GET                 |
    Then the step should succeed
    And the output should contain:
      | es_cluster_nodes_number          |
      | es_cluster_shards_active_percent |

  # @author qitang@redhat.com
  # @case_id OCP-22050
  @admin
  @destructive
  Scenario: Elasticsearch using dynamic volumes
    And default storageclass is stored in the :default_sc clipboard
    Given I delete the clusterlogging instance
    Then the step should succeed
    Given I use the "openshift-logging" project
    And I register clean-up steps:
    """
    Given I delete the clusterlogging instance
    Then the step should succeed
    And I run the :delete client command with:
      | object_type | pvc               |
      | all         | true              |
      | n           | openshift-logging |
    Then the step should succeed
    """
    Given I obtain test data file "logging/clusterlogging/clusterlogging-storage-template.yaml"
    When I process and create:
      | f | clusterlogging-storage-template.yaml |
      | p | STORAGE_CLASS=<%= cb.default_sc.name %>                                                      |
      | p | PVC_SIZE=10Gi                                                                                |
    Then the step should succeed
    Given I wait for the "instance" clusterloggings to appear
    And the expression should be true> cluster_logging('instance').logstore_storage_class_name == cb.default_sc.name
    Given I wait for the "elasticsearch" elasticsearches to appear
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['storage']['storageClassName'] == cb.default_sc.name
    Given I wait for clusterlogging with "fluentd" log collector to be functional in the project
    Given I wait up to 300 seconds for the steps to pass:
    """
    Given evaluation of `elasticsearch('elasticsearch').nodes[0]['genUUID']` is stored in the :gen_uuid clipboard
    And the expression should be true> cb.gen_uuid != nil
    """
    Given a pod becomes ready with labels:
      | component=elasticsearch |
    And the expression should be true> pod.volume_claims.first.name.include? "elasticsearch-elasticsearch-cdm" and pod.volume_claims.first.name.include? cb.gen_uuid
    And the expression should be true> persistent_volume_claim(pod.volume_claims.first.name).exists?

  # @author qitang@redhat.com
  # @case_id OCP-30776
  @admin
  @destructive
  @commonlogging
  Scenario: Elasticsearch6 new data modle indices
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    #When I login to kibana logging web console
    #Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cat/indices?format=JSON |
      | op           | GET                      |
    Then the step should succeed
    And the output should contain:
      | app-00    |
      | infra-00  |
      | .kibana_  |
      | .security |
