@clusterlogging
Feature: Elasticsearch related tests

  # @auther qitang@redhat.com
  # @case_id OCP-22050
  @admin
  @destructive
  Scenario: Elasticsearch using dynamic volumes
    Given I switch to cluster admin pseudo user
    And default storageclass is stored in the :default_sc clipboard
    Given I delete the clusterlogging instance
    Then the step should succeed
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/clusterlogging/example_unmanaged.yaml |
    Then the step should succeed
    Given I use the "openshift-logging" project
    Given I wait for the "instance" clusterloggings to appear
    Given I get project clusterlogging named "instance" as YAML
    Then the step should succeed
    And the output should contain:
      | managementState: Unmanaged |
    Given I get project elasticsearch named "elasticsearch" as YAML
    Then the step should fail
    When I run the :patch client command with:
      | resource      | clusterlogging                                                                                        |
      | resource_name | instance                                                                                              |
      | p             | {"spec":{"logStore":{"elasticsearch":{"storage":{"storageClassName": "<%= cb.default_sc.name %>"}}}}} |
      | type          | merge                                                                                                 |
    Then the step should succeed
    Given I get project clusterlogging named "instance" as YAML
    And the output should contain:
      | storageClassName: <%= cb.default_sc.name %> |
      | managementState: Unmanaged                  |
    Given I get project elasticsearch named "elasticsearch" as YAML
    Then the step should fail
    When I run the :patch client command with:
      | resource      | clusterlogging                         |
      | resource_name | instance                               |
      | p             | {"spec":{"managementState":"Managed"}} |
      | type          | merge                                  |
    Then the step should succeed
    Given I get project clusterlogging named "instance" as YAML
    And the output should contain:
      | storageClassName: <%= cb.default_sc.name %>   |
      | managementState: Managed                      |
    Given I wait for the "elasticsearch" elasticsearches to appear
    Given I get project elasticsearch named "elasticsearch" as YAML
    Then the step should succeed
    And the output should contain:
      | storageClassName: <%= cb.default_sc.name %>   |
      | managementState: Managed                      |
    And evaluation of `@result[:parsed]["spec"]["nodes"][0]["genUUID"]` is stored in the :gen_uuid clipboard

    Given a pod becomes ready with labels:
      | component=elasticsearch |
    And the expression should be true> pod.volume_claims.first.name.include? "elasticsearch-elasticsearch-cdm" and pod.volume_claims.first.name.include? cb.gen_uuid
    Given I wait until the ES cluster is healthy
    Given I delete the clusterlogging instance
    Then the step should succeed
    And I run the :delete client command with:
      | object_type | pvc  |
      | all         | true |
    Then the step should succeed


