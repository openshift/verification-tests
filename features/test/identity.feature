Feature: test files related steps

  Scenario: test identity and user
    Given I restore user's context after scenario
    Then the step should succeed
    And admin ensures identity "ns" is deleted
    Then the step should succeed
