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

  Scenario: mistaken nested ERB expression still should not fail
    Given the expression should be true> cb.test = ["1", "2", "3"]
    When I repeat the following steps for each :item in cb.test:
    """
    Then I log the message> an item in "<%= cb.test %>: #{cb.item}"
    """
