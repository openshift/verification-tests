Feature: kata installation feature
  # @author valiev@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: full kata installation
    Given Verify catalog source existence
    Given Install Kata operator
    Given Apply "example-kataconfig" kataconfig
    Given Deploy "example" pod with kata runtime
