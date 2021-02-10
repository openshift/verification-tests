Feature: kata related features
  # @author pruan@redhat.com
  # @case_id OCP-36508
  @admin
  @destructive
  @upgrade-prepare
  Scenario: kata container operator installation
    Given the master version >= "4.6"
    Given kata container has been installed successfully in the "kata-operator" project
    And I verify kata container runtime is installed into the a worker node

  # @author pruan@redhat.com
  # @case_id OCP-36509
  @admin
  @destructive
  @upgrade-prepare
  Scenario: test delete kata installation
    Given the master version >= "4.6"
    Given I switch to cluster admin pseudo user
    And I remove kata operator from "kata-operator" namespace


  Scenario: test install kata-webhook
    Given I have a project
    And evaluation of `project.name` is stored in the :test_project_name clipboard
    And I run oc create over ERB test file: kata/webhook/example-fedora.yaml
    And the pod named "example-fedora" becomes ready
    Then the expression should be true> pod.runtime_class_name == 'kata'
