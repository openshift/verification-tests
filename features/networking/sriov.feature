Feature: Sriov related scenarios

  # @author zzhao@redhat.com
  # @case_id OCP-29944
  @admin
  Scenario: sriov operator can be setup and running well
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sriov-network-operator" project
    And all existing pods are ready with labels:
      | app=network-resources-injector  |
    And all existing pods are ready with labels:
      | app=operator-webhook            |
    And all existing pods are ready with labels:
      | app=sriov-network-config-daemon |
    And status becomes :running of exactly 1 pods labeled:
      | name=sriov-network-operator     |
