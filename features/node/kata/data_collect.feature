Feature: kata data collect tests and scenarios
  # @author valiev@redhat.com
  # @case_id OCP-42162
  @admin
  @destructive

  Scenario: Must-gather command works with a specific image
    Given Pre-test checks
    Given I run must-gather command
