Feature: some meta step tests

  Scenario: Loop over the clipboard
    Given expression should be true> cb.testvars = [1,2,3,4]
    When I repeat the following steps for each :testvar in cb.testvars:
    """
    Given I log the message> #{cb.testvar}
    Then the output should equal "#{cb.testvar}"
    """
    Then the output should equal "4"

  Scenario: steps loop test
    Given evaluation of `0` is stored in the :test clipboard
    When I run the steps 3 times:
    """
    Given the expression should be true> cb.test == cb.i - 1
    When evaluation of `cb.test + 1` is stored in the :test clipboard
    Then the expression should be true> cb.i == cb.test
    # the curly expression evaluates once before each iteration thus..
    And  the expression should be true> cb.i == #{cb.test}
    """
    Then the expression should be true> cb.test = 3
