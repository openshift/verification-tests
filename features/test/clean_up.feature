Feature: some clean up steps testing

  Scenario: define clean-up in different ways
    Given I register clean-up steps:
      |I log the message> Message 1  |
      |I log the messages:           |
      |! Message 2!Message 3!        |
    And I register clean-up steps:
    """
    I log the messages:
      | Message 4 | Message 5 |
      | Message 6 | Message 7 |
    I log the message> Message 8
    I fail the scenario
    """
    Then I do nothing

  Scenario: conditional clean-up
    Given I register skippable clean-up steps based on the :test1 clipboard:
    """
    I log the message> You shouldn't see this
    the expression should be true> false
    """
    And evaluation of `true` is stored in the :test1 clipboard
    And I register clean-up steps:
    """
    the output should contain "Message 3"
    """
    And I register skippable clean-up steps based on the :test2 clipboard:
    """
    I log the message> Message 1
    the output should contain "Message 1"
    I log the message> Message 2
    the output should contain "Message 2"
    I log the message> Message 3
    """
