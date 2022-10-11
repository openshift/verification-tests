Feature: pod testing scenarios

  Scenario: Show pod info when pod not ready to easier debug
    Given I have a project
    When I run the :new_app client command with:
      | template | mysql-persistent |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=mysql |
    And a pod becomes ready with labels:
      | name=test-label-does-not-exist |
