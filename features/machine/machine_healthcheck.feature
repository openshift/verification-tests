Feature: MachineHealthCheck Test Scenarios

  # @author jhou@redhat.com
  # @case_id OCP-25897
  @admin
  @destructive
  @aws-ipi
  @gcp-ipi
  @4.10 @4.9
  @vsphere-ipi
  Scenario: Remediation should be applied when the unhealthyCondition 'Ready' is met
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-25897"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machine_health_check is deleted after scenario

    # Create unhealthyCondition to trigger machine remediation
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated

    # Verify when a machine is deleted, the node is drained(even if it's unreachable)
    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>    |
      | c             | machine-controller |
    Then the output should contain:
      | drain successful for machine "<%= machine.name %>" |

  # @author jhou@redhat.com
  # @case_id OCP-26311
  @admin
  @destructive
  @aws-ipi
  @gcp-ipi
  @4.10 @4.9
  @vsphere-ipi
  Scenario: Create a machinehealthcheck when there is already an unhealthy machine
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-26311"

    # Create unhealthyCondition before createing a MHC
    Given I create the 'Ready' unhealthyCondition

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machine_health_check is deleted after scenario

    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25734
  @admin
  @destructive
  @aws-ipi
  @gcp-ipi
  @4.10 @4.9
  @vsphere-ipi
  Scenario: Create multiple MHCs to monitor same machineset
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-25734"

    # Create MHCs
    Given I run the steps 2 times:
    """
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                 |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-#{ cb.i } |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>            |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>               |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-#{ cb.i }" machine_health_check is deleted after scenario
    """

    # Create unhealthyCondition before createing a MHC
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25691
  @admin
  @destructive
  @aws-ipi
  @gcp-ipi
  @4.10 @4.9
  @vsphere-ipi
  Scenario: Use "maxUnhealthy" to prevent automated remediation
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario
    Given I clone a machineset and name it "machineset-clone-25691"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api         |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-1 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 0                             |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-1" machine_health_check is deleted after scenario
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api         |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %>-2 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 90%                           |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>-2" machine_health_check is deleted after scenario

    # Create unhealthyCondition to trigger machine remediation
    Given I create the 'Ready' unhealthyCondition
    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |
    And I wait up to 600 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>                |
      | c             | machine-healthcheck-controller |
    Then the output should contain:
      | mhc-<%= machine_set.name %>-1: total targets: 1,  maxUnhealthy: 0, unhealthy: 1. Short-circuiting remediation   |
      | mhc-<%= machine_set.name %>-2: total targets: 1,  maxUnhealthy: 90%, unhealthy: 1. Short-circuiting remediation |
    """
    When I run the :describe admin command with:
      | resource | machinehealthcheck/mhc-<%= machine_set.name %>-2 |
    Then the output should match:
      | Type.*RemediationAllowed |

  # @author miyadav@redhat.com
  # @case_id OCP-28718
  @admin
  @destructive
  @4.10 @4.9
  Scenario: [MHC] - Machine Node startup timeout should be configurable
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-28718"

    # Create MHC with configurable node startup timeout
    Given I obtain test data file "cloud/mhc/mhc_configurabletimeout.yaml"
    When I run oc create over "mhc_configurabletimeout.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
      | ["spec"]["nodeStartupTimeout" ]                                                    | 15m                         |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machine_health_check is deleted after scenario

    Given I create the 'Ready' unhealthyCondition
    Then a pod becomes ready with labels:
     | api=clusterapi, k8s-app=controller |

    And I wait up to 600 seconds for the steps to pass:
    """
     When I run the :logs admin command with:
     | resource_name | <%= pod.name %>                |
     | c             | machine-healthcheck-controller |
    Then the output should contain:
     | Ensuring a requeue happens in 15m0  |
    """
   Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25727
  @admin
  @destructive
  @4.10 @4.9
  Scenario: Remediation should be applied when machine has nodeRef but node is deleted
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-25727"

    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machine_health_check is deleted after scenario

    Given I store the last provisioned machine in the :new_machine clipboard
    Given admin ensures "<%= machine(cb.new_machine).node_name %>" node is deleted
    Then the machine named "<%= cb.new_machine %>" should be remediated

  # @author miyadav@redhat.com
  # @case_id OCP-29857
  @admin
  Scenario: [MHC] MaxUnhealthy should not allow malformed values
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project
    And evaluation of `BushSlicer::Machine.list(user: admin, project: project('openshift-machine-api'))` is stored in the :machines clipboard

    # Create MHC with malformed unhealthy nodes value and empty selectors
    Given I obtain test data file "cloud/mhc/mhc_malformed.yaml"
    When I run oc create over "mhc_malformed.yaml" replacing paths:
      | n  | openshift-machine-api |
    Then the step should succeed
    And I ensure "mhc-malformed" machine_health_check is deleted after scenario

    Then a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |

    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>                |
      | c             | machine-healthcheck-controller |
    Then the output should contain:
      | remediation won't be allowed: invalid value for IntOrString  |
      | total targets: <%= cb.machines.count %>                      | #This covers OCP-29062 - empty selectors watches all machines in cluster

  # @author miyadav@redhat.com
  # @case_id OCP-28859
  @admin
  @destructive
  @4.10 @4.9
  Scenario: MHC MaxUnhealthy string value should be checked for '%' symbol
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-28859"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api       |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set.name %>     |
      | ["spec"]["maxUnhealthy"]                                                           | "1%"                        |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set.name %>" machine_health_check is deleted after scenario

    Then a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |

    Given I create the 'Ready' unhealthyCondition

    And I wait up to 600 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>                |
      | c             | machine-healthcheck-controller |
    Then the output should contain:
      | mhc-<%= machine_set.name %>: total targets: 1,  maxUnhealthy: 1%, unhealthy: 1. Short-circuiting remediation |
    """

  # @author miyadav@redhat.com
  # @case_id OCP-33714
  @admin
  @4.10 @4.9
  Scenario: Leverage OpenAPI validation within MHC
    Given I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project

    Given I obtain test data file "cloud/mhc/mhc_validations.yaml"
    Given evaluation of `["-2a", "10t%", "-2%"]` is stored in the :resources clipboard
    And I repeat the following steps for each :resource in cb.resources:
    """
    When I run oc create over "mhc_validations.yaml" replacing paths:
      | ["spec"]["maxUnhealthy"] | #{cb.resource} |
    Then the output should match:
      | maxUnhealthy: Invalid value: ".*": spec.maxUnhealthy |
    """

  # @author miyadav@redhat.com
  # @case_id OCP-34095
  @admin
  @4.10 @4.9
  Scenario: [mhc] timeout field without units(h,m,s) shoud not be allowed to be stored
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project

    Given I obtain test data file "cloud/mhc/mhc_validations.yaml"
    Given evaluation of `["3", "3t"]` is stored in the :timeouts clipboard
    And I repeat the following steps for each :timeout in cb.timeouts:
    """
    When I run oc create over "mhc_validations.yaml" replacing paths:
      | ["spec"]["unhealthyConditions"][0]["timeout"] | #{cb.timeout} |
    Then the output should match:
      | timeout: Invalid value: ".*": spec.unhealthyConditions.timeout |
    """
