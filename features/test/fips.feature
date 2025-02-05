Feature: fips enabled test

  @admin @fips
  Scenario: FIPS mode checking command without exiting
    And I skip testcase if fips is enabled inside node
    And I create the "foo-bar" directory
