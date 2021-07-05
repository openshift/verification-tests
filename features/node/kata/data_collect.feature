Feature: kata data collect tests
  # @author valiev@redhat.com
  # @case_id OCP-42162
  @admin
  Background:
    Given kata container has been installed successfully
    Then the expression should be true> project.name == 'openshift-sandboxed-containers-operator'

  Scenario: Must-gather command works with a specific image
    Given I run must-gather command

