Feature: kata data collect tests and scenarios
  # @author valiev@redhat.com
  # @case_id OCP-42162
  @admin
  @destructive
  
  Scenario: Must-gather command works with a specific image	
    Given Apply "full" test setup
    Given I run must-gather command
