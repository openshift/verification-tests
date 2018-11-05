Feature: SDN related test scenarios

  @admin
  Scenario: Add annotations to the default netnamespace
    Given admin adds following annotations to the "default" netnamespace:
      | test=true |
    Then the step should succeed

  @admin
  Scenario: Add annotations and overwrites them in the default netnamespace
    Given admin adds following annotations to the "default" netnamespace:
      | test=true |
    Then the step should succeed
    Given admin adds and overwrites following annotations to the "default" netnamespace:
      | test=false |
    Then the step should succeed
