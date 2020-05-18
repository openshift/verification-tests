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
    | cluster_operator     |
    | "machine-api"        | # @case_id OCP-22712
    | "cluster-autoscaler" | # @case_id OCP-27664


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

    Given I clone a machineset and name it "machineset-clone-22612"

    Given I scale the machineset to +2
    Then the step should succeed
    And the machineset should have expected number of running machines

    When I scale the machineset to -1
    Then the step should succeed
    And the machineset should have expected number of running machines
