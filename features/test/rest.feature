Feature: Testing REST Scenarios

  Scenario: simple rest scenario
    When I perform the :create_project_request rest request with:
      | project name | demo |
      | display name | OpenShift 3 Demo |
      | description  | This is the first demo project with OpenShift v3 |
    Then the step should succeed
    # timing issue, making sure the project is there fist
    And I use the "demo" project
    When I perform the :list_projects rest request
    Then the step should succeed
    And the output should contain:
      | OpenShift 3 Demo |
      | Active |
    When I switch to the second user
    And I perform the :list_projects rest request
    Then the step should succeed
    And the output should not contain:
      | demo |
    When I switch to the first user
    And I perform the :delete_project rest request with:
      | project name | demo |
    Then the step should succeed

  Scenario: cli command before rest
    Given I run the :delete client command with:
      | object_type | project |
      | object_name_or_id | demo |
    And I perform the :list_projects rest request
    Then the step should succeed
    And the output should not contain:
      | demo |
