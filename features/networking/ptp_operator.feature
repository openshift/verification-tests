Feature: PTP related scenarios

  # @author huirwang@redhat.com
  # @case_id OCP-25940
  @admin
  Scenario: ptp operator can be deployed successfully
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ptp" project
    #check ptp related pods are ready in openshift-ptp projects
    And all existing pods are ready with labels:
      | app=linuxptp-daemon |
    And status becomes :running of exactly 1 pods labeled:
      | name=ptp-operator |
