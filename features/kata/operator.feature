Feature: kata operator related tests
  Background:
  Given valid cluster type for kata tests exists

  # @author valiev@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: operator successfully installed
    Given catalogsource "redhat-operators" exists in "openshift-marketplace" namespace
    When I install sandboxed-operator in "openshift-sandboxed-containers-operator" namespace
    Then sandboxed-operator operator should be installed and running
