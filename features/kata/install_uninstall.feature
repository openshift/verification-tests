Feature: kata related features
  # @author pruan@redhat.com
  # @case_id OCP-36508
  @admin
  @destructive
  Scenario: kata container operator installation
    Given kata container has been installed successfully in the "openshift-sandboxed-containers-operator" project
    And I verify kata container runtime is installed into a worker node

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
    Given the kata-operator is installed using OLM GUI

  # @author pruan@redhat.com
  # @case_id OCP-39499
  @admin
  @destructive
  Scenario: kata operator can be installed via CLI with OLM for OCP>=4.8
    Given the kata-operator is installed using OLM CLI

  # @author pruan@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: install kata, verify pod has kata runtime followed by uninstall kata from cluster
    Given the kata-operator is installed using OLM CLI
    And I verify kata container runtime is installed into a worker node
    And I ensure "<%= project.name %>" project is deleted
    And I remove kata operator from the namespace
