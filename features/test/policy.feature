Feature: Add admin user to current project

  Scenario: Add admin user to current project
    When I create a new project
    Then the step should succeed
    When I give project admin role to the second user
    Then the step should succeed
    When I remove project admin role from the second user
    Then the step should succeed
    Given the third user is cluster-admin

