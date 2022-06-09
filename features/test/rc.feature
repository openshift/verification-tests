Feature: rc related test

  Scenario: test new rc ready method
    Given I have a project
    Given I store all replicationcontrollers in the project to the clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a replicationController becomes ready with labels:
      | name=test-rc |
    Then the expression should be true> rc.name == 'test-rc'
    And I wait until replicationController "test-rc" is ready
    And the expression should be true> rc.ready_replicas(user: user) == 2
    And the expression should be true> rc.expected_replicas == 2
    And the expression should be true> rc.current_replicas == 2
    And status becomes :running of exactly 2 pods labeled:
      | name=test-pods |
