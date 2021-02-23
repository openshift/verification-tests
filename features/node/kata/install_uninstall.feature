Feature: kata related features
  # @author pruan@redhat.com
  # @case_id OCP-36508
  @admin
  @destructive
  Scenario: kata container operator installation
    Given the master version >= "4.6"
    Given kata container has been installed successfully in the "kata-operator" project
    And I verify kata container runtime is installed into the a worker node

  # @author pruan@redhat.com
  # @case_id OCP-36509
  @admin
  @destructive
  Scenario: test delete kata installation
    Given I remove kata operator from the namespace


  Scenario: test install kata-webhook
    Given I have a project
    And evaluation of `project.name` is stored in the :test_project_name clipboard
    And I run oc create over ERB test file: kata/webhook/example-fedora.yaml
    And the pod named "example-fedora" becomes ready
    Then the expression should be true> pod.runtime_class_name == 'kata'

  # @author pruan@redhat.com
  # @case_id OCP-39344
  @admin
  @destructive
  Scenario: Operator can be installed through web console
    Given the master version >= "4.7"
    Given the kata-operator is installed using OLM GUI


  # @author pruan@redhat.com
  # @case_id OCP-39499
  @admin
  @destructive
  Scenario: kata operator can be installed via CLI with OLM for OCP>=4.7
    Given the master version >= "4.7"
    Given the kata-operator is installed using OLM CLI
