Feature: test some transformations

  Scenario: Some Transformations
    Given I log the message> some <%= "message" %> with double <%= "expand" %>
    Then the output should contain:
      | message              |
      | <%= "exp" + "and" %> |
    And the output should match "[-a-zA-Z0-9_ ]+"

  Scenario Outline: Transformations in Outline
    Given I log the message> some <message>
    Then the output should contain "example message"

    Examples:
      | message                       |
      | <%= "example " + "message" %> |
