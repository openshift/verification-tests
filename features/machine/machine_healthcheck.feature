Feature: MachineHealthCheck Test Scenarios

  # @author jhou@redhat.com
  # @case_id OCP-25897
  @admin
  @destructive
  Scenario: Remediation should be applied when the unhealthyCondition 'Ready' is met
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I pick a random machineset to scale
    # Create MHC
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machinehealthcheck is deleted after scenario

    # Create unhealthyCondition to trigger machine remediation
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated
