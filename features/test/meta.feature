Feature: some meta step tests

  Scenario: Loop over the clipboard
    Given expression should be true> cb.testvars = [1,2,3,4]
    When I repeat the following steps for each :testvar in cb.testvars:
    """
    Given I log the message> #{cb.testvar}
    Then the output should equal "#{cb.testvar}"
    """
    Then the output should equal "4"
