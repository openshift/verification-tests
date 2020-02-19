Feature: basic verification for upgrade testing
  # @case_id OCP-26309
  @upgrade-check
  Scenario: simple selector upgrade test case
    Given I log the message> Hi Check!

  @upgrade-prepare
  Scenario: simple selector upgrade test case - prepare
    Given I log the message> Hi Prepare!
