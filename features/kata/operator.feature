Feature: kata operator related tests
  Background:
  Given valid cluster type for kata tests exists

  # @author valiev@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: operator successfully installed
    Given catalogsource "redhat-operators" exists in "openshift-marketplace" namespace
    When i install sandboxed-operator in "openshift-sandboxed-containers-operator" namespace
    Then operator should be up and running
