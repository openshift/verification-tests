Feature: rc related test

  Scenario: test new rc ready method
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
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

