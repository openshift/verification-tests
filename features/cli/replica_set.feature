Feature: replicaSet related tests

  # @author pruan@redhat.com
  # @case_id OCP-10917
  @smoke
  Scenario: OCP-10917:Workloads Support endpoints of RS in OpenShift
    Given I have a project
    Given I obtain test data file "replicaSet/ocp10917/rs_endpoints.yaml"
    When I run the :create client command with:
      | f | rs_endpoints.yaml |
    Then the step should succeed
    And I wait until number of replicas match "3" for replicaSet "frontend"
    When I run the :patch client command with:
      | resource      | rs                      |
      | resource_name | frontend                |
      | p             | {"spec":{"replicas":4}} |
    Then the step should succeed
    And I wait until number of replicas match "4" for replicaSet "frontend"
    When I run the :delete client command with:
      | object_type       | rs       |
      | object_name_or_id | frontend |
    Then the step should succeed
    # verified that the rs is gone
    When I run the :get client command with:
      | resource      | rs       |
      | resource_name | frontend |
    Then the step should not succeed
    And the output should contain:
      | "frontend" not found |

