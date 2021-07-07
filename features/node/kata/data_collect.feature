Feature: kata data collect tests
  # @author valiev@redhat.com
  # @case_id OCP-42162
  @admin
  @destructive
  Background:
    Given the kata-operator is installed using OLM CLI
    And I verify kata container runtime is installed into a worker node
    And evaluation of `project.name` is stored in the :test_project_name clipboard
    And I run oc create over ERB test file: kata/webhook/example-fedora.yaml
    And the pod named "example-fedora" becomes ready
    Then the expression should be true> pod.runtime_class_name == 'kata'

  Scenario: Must-gather command works with a specific image
    Given I run must-gather command
