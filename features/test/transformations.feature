Feature: test some transformations
  Scenario: Some Transformations
    Given I log the message> some <%= "message" %> with double <%= "expand" %>
    Then the output should contain:
      |message|
      |expand|
    And the output should match "[-a-zA-Z0-9_ ]+"
