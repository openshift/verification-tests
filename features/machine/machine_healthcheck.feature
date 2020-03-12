Feature: MachineHealthCheck Test Scenarios

  # @author jhou@redhat.com
  # @case_id OCP-25897
  @admin
  @destructive
  Scenario: Remediation should be applied when the unhealthyCondition 'Ready' is met
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I clone a machineset named "machineset-25897"
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

  # @author jhou@redhat.com
  # @case_id OCP-26311
  @admin
  @destructive
  Scenario: Create a machinehealthcheck when there is already an unhealthy machine
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I clone a machineset named "machineset-26311"

    # Create unhealthyCondition before createing a MHC
    Given I create the 'Ready' unhealthyCondition

    # Create MHC
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machinehealthcheck is deleted after scenario

    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25734
  @admin
  @destructive
  Scenario: Create multiple MHCs to monitor same machineset
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I clone a machineset named "machineset-25734"

    # Create MHCs
    Given I run the steps 2 times:
    """
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/mhc/mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                 |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-#{ cb.i } |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>            |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>               |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-#{ cb.i }" machinehealthcheck is deleted after scenario
    """

    # Create unhealthyCondition before createing a MHC
    When I create the 'Ready' unhealthyCondition

    Then the machine should be remediated
