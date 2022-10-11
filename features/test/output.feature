Feature: Output inspections

  Scenario: the output by order should contain/match
    When I log the messages:
      | string 1 |
      | string 2 |
      | string 3 |
      | string 4 |
      | string 5 |
    Then the step should succeed
    And the output by order should contain:
      | string 2 |
      | string 4 |
      | string 5 |
    And the output by order should match:
      | st..ng 1 |
      | st..ng 3 |
      | st..ng 4 |
    And the output by order should not contain:
      | string 1 |
      | string 5 |
      | string 4 |
    And the output by order should not match:
      | st..ng 1 |
      | st..ng 5 |
      | st..ng 4 |

  Scenario: the output by order "should contain" negative
    When I log the messages:
      | string 1 |
      | string 2 |
      | string 3 |
      | string 4 |
      | string 5 |
    Then the output by order should contain:
      | string 3 |
      | string 2 |

  Scenario: the output by order "should match" negative
    When I log the messages:
      | string 1 |
      | string 2 |
      | string 3 |
      | string 4 |
      | string 5 |
    Then the output by order should match:
      | string 3 |
      | string 2 |

  Scenario: the output by order "should not match" negative
    When I log the messages:
      | string 1 |
      | string 2 |
      | string 3 |
      | string 4 |
      | string 5 |
    Then the output by order should not match:
      | string 2 |
      | string 3 |

  Scenario: the output by order "should not contain" negative
    When I log the messages:
      | string 1 |
      | string 2 |
      | string 3 |
      | string 4 |
      | string 5 |
    Then the output by order should not contain:
      | string 2 |
      | string 3 |
