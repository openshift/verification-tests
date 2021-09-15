Feature: Machine-api components upgrade tests
  @upgrade-prepare
  Scenario Outline: Cluster operator should be available after upgrade - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  Examples:
    | cluster_operator     |
    | "machine-api"        |
    | "cluster-autoscaler" |

  # @author jhou@redhat.com
  @upgrade-check
  @admin
  Scenario Outline: Cluster operator should be available after upgrade
    Given evaluation of `cluster_operator(<cluster_operator>).condition(type: 'Available')` is stored in the :co_available clipboard
    Then the expression should be true> cb.co_available["status"]=="True"

    Given evaluation of `cluster_operator(<cluster_operator>).condition(type: 'Degraded')` is stored in the :co_degraded clipboard
    Then the expression should be true> cb.co_degraded["status"]=="False"

    Given evaluation of `cluster_operator(<cluster_operator>).condition(type: 'Upgradeable')` is stored in the :co_upgradable clipboard
    Then the expression should be true> cb.co_upgradable["status"]=="True"

    Given evaluation of `cluster_operator(<cluster_operator>).condition(type: 'Progressing')` is stored in the :co_progressing clipboard
    Then the expression should be true> cb.co_progressing["status"]=="False"

  Examples:
    | cluster_operator           |
    | "machine-api"              | # @case_id OCP-22712
    | "cluster-autoscaler"       | # @case_id OCP-27664
    | "cloud-controller-manager" | # @case_id OCP-43331


  @upgrade-prepare
  Scenario: There should be no pending or firing alerts for machine-api operators - prepare
    Given the expression should be true> "True" == "True"

  # @author jhou@redhat.com
  # @case_id OCP-22692
  @upgrade-check
  @admin
  Scenario: There should be no pending or firing alerts for machine-api operators
    Given I switch to cluster admin pseudo user

    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                                                                                                                     |
      | query | AlERTS{alertname="ClusterAutoscalerOperatorDown\|MachineAPIOperatorDown\|ClusterMachineApproverDown",alertstate="pending\|firing"} |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["status"] == "success"
    And the expression should be true> @result[:parsed]["data"]["result"].length == 0


  @upgrade-prepare
  Scenario: Scale up and scale down a machineSet after upgrade - prepare
    Given the expression should be true> "True" == "True"

  # @author jhou@redhat.com
  # @case_id OCP-22612
  @upgrade-check
  @admin
  @destructive
  Scenario: Scale up and scale down a machineSet after upgrade
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-22612"

    Given I scale the machineset to +2
    Then the step should succeed
    And the machineset should have expected number of running machines

    When I scale the machineset to -1
    Then the step should succeed
    And the machineset should have expected number of running machines

  @upgrade-prepare
  @admin
  @destructive
  Scenario Outline: Spot/preemptible instances should not block upgrade - prepare
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And I pick a random machineset to scale

    # Create a machineset
    Given I get project machineset named "<%= machine_set.name %>" as YAML
    And I save the output to file> <machineset_name>.yaml
    And I replace content in "<machineset_name>.yaml":
      | <%= machine_set.name %> | <machineset_name> |
      | /replicas.*/            | replicas: 0       |

    When I run the :create admin command with:
      | f | <machineset_name>.yaml |
    Then the step should succeed

    Given as admin I successfully merge patch resource "machineset/<machineset_name>" with:
      | {"spec":{"replicas":1,"template":{"spec":{"providerSpec":{"value":{<value>}}}}}} |

    # Verify machine could be created successful
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set("<machineset_name>").desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

    And "machine-api-termination-handler" daemonset becomes ready in the "openshift-machine-api" project
    And 1 pod becomes ready with labels:
      | k8s-app=termination-handler |

    Examples:
      | iaas_type | machineset_name        | value                   |
      | aws       | machineset-clone-41175 | "spotMarketOptions": {} | # @case_id OCP-41175
      | gcp       | machineset-clone-41803 | "preemptible": true     | # @case_id OCP-41803
      | azure     | machineset-clone-41804 | "spotVMOptions": {}     | # @case_id OCP-41804

  # @author zhsun@redhat.com
  @upgrade-check
  @admin
  @destructive
  Scenario Outline: Spot/preemptible instances should not block upgrade
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures "<machineset_name>" machineset is deleted after scenario

    Given "machine-api-termination-handler" daemonset becomes ready in the "openshift-machine-api" project
    And 1 pod becomes ready with labels:
      | k8s-app=termination-handler |

    Given admin ensures "<machineset_name>" machineset is deleted
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | machine                                      |
      | l        | machine.openshift.io/interruptible-instance= |
    Then the step should succeed
    And the output should not contain:
      | <machineset_name> |
    """

    Examples:
      | iaas_type | machineset_name        | value                   |
      | aws       | machineset-clone-41175 | "spotMarketOptions": {} | # @case_id OCP-41175
      | gcp       | machineset-clone-41803 | "preemptible": true     | # @case_id OCP-41803
      | azure     | machineset-clone-41804 | "spotVMOptions": {}     | # @case_id OCP-41804
      
  @upgrade-prepare
  @admin
  Scenario: Cluster should automatically scale up and scale down with clusterautoscaler deployed - prepare
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project

    Given I obtain test data file "cloud/cluster-autoscaler.yml"
    When I run the :create admin command with:
      | f | cluster-autoscaler.yml |
    Then the step should succeed
    And 1 pod becomes ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

  # @author jhou@redhat.com
  # @case_id OCP-30783
  @upgrade-check
  @admin
  @destructive
  Scenario: Cluster should automatically scale up and scale down with clusterautoscaler deployed
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-30783"

    # Delete clusterautoscaler after scenario
    Given admin ensures "default" clusterautoscaler is deleted after scenario

    # Create machineautoscaler
    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                 |
      | ["spec"]["minReplicas"]            | 1                       |
      | ["spec"]["maxReplicas"]            | 3                       |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario

    # Create workload
    Given I obtain test data file "cloud/autoscaler-auto-tmpl.yml"
    When I run the :create admin command with:
      | f | autoscaler-auto-tmpl.yml |
    Then the step should succeed
    And admin ensures "workload" job is deleted from the "openshift-machine-api" project after scenario

    # Verify machineset has scaled
    Given I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines
