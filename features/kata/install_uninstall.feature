Feature: kata install/uninstall related features
  Background:
  Given a valid cluster type for kata tests exists
  
  # @author valiev@redhat.com
  # @case_id OCP-41813
  @admin
  @destructive
  Scenario: operator successfully installed
    Given Catalog source "redhat-operators" exists in "openshift-marketplace" namespace
    When I install sandboxed-operator in "openshift-sandboxed-containers-operator" namespace
    Then Operator should be up and running
