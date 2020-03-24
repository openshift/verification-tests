@clusterlogging
Feature: Elasticsearch related tests

  # @author qitang@redhat.com
  # @case_id OCP-21487
  @admin
  @destructive
  @commonlogging
  Scenario: Elasticsearch Prometheus metrics can be accessed.
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _prometheus/metrics |
      | op           | GET                 |
    Then the step should succeed
    And the output should contain:
      | es_cluster_nodes_number                   |
      | es_cluster_shards_active_percent          |

  # @author qitang@redhat.com
  # @case_id OCP-22050
  @admin
  @destructive
  Scenario: Elasticsearch using dynamic volumes
    And default storageclass is stored in the :default_sc clipboard
    Given I delete the clusterlogging instance
    Then the step should succeed
    Given I use the "openshift-logging" project
    And I run the :create client command with:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/logging/clusterlogging/example_unmanaged.yaml |
    Then the step should succeed
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
    Given I wait for the "instance" clusterloggings to appear
    Then the expression should be true> cluster_logging('instance').management_state == "Unmanaged"
    And the expression should be true> elasticsearch('elasticsearch').exists? == false
    When I run the :patch client command with:
      | resource      | clusterlogging                                                                                        |
      | resource_name | instance                                                                                              |
      | p             | {"spec":{"logStore":{"elasticsearch":{"storage":{"storageClassName": "<%= cb.default_sc.name %>"}}}}} |
      | type          | merge                                                                                                 |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').management_state == "Unmanaged" and cluster_logging('instance').logstore_storage_class_name == cb.default_sc.name
    And the expression should be true> elasticsearch('elasticsearch').exists? == false
    When I run the :patch client command with:
      | resource      | clusterlogging                         |
      | resource_name | instance                               |
      | p             | {"spec":{"managementState":"Managed"}} |
      | type          | merge                                  |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').management_state == "Managed" and cluster_logging('instance').logstore_storage_class_name == cb.default_sc.name
    Given I wait for the "elasticsearch" elasticsearches to appear
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['storage']['storageClassName'] == cb.default_sc.name
    And the expression should be true> elasticsearch('elasticsearch').management_state == "Managed"
    And evaluation of `elasticsearch('elasticsearch').nodes[0]["genUUID"]` is stored in the :gen_uuid clipboard

    Given a pod becomes ready with labels:
      | component=elasticsearch |
    And the expression should be true> pod.volume_claims.first.name.include? "elasticsearch-elasticsearch-cdm" and pod.volume_claims.first.name.include? cb.gen_uuid
    Given I wait until the ES cluster is healthy
