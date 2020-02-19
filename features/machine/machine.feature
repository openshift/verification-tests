Feature: Machine features testing

  # @author jhou@redhat.com
  # @case_id OCP-21196
  @smoke
  Scenario: Machines should be linked to nodes
    Given I have an IPI deployment
    Then the machines should be linked to nodes

  # @author jhou@redhat.com
  # @case_id OCP-22115
  @smoke
  Scenario: machine-api clusteroperator should be in Available state
    Given evaluation of `cluster_operator('machine-api').condition(type: 'Available')` is stored in the :co_available clipboard
    Then the expression should be true> cb.co_available["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Degraded')` is stored in the :co_degraded clipboard
    Then the expression should be true> cb.co_degraded["status"]=="False"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Upgradeable')` is stored in the :co_upgradable clipboard
    Then the expression should be true> cb.co_upgradable["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Progressing')` is stored in the :co_progressing clipboard
    Then the expression should be true> cb.co_progressing["status"]=="False"

  # @author jhou@redhat.com
  # @case_id OCP-25436
  @admin
  @destructive
  Scenario: Scale up and scale down a machineSet
    Given I have an IPI deployment
    And I pick a random machineset to scale
    And evaluation of `machine_set.available_replicas` is stored in the :replicas_to_restore clipboard

    Given I scale the machineset to +2
    And I register clean-up steps:
    """
    When I scale the machineset to <%= cb.replicas_to_restore %>
    Then the machineset should have expected number of running machines
    """
    Then the step should succeed
    And the machineset should have expected number of running machines

    When I scale the machineset to -1
    Then the step should succeed
    And the machineset should have expected number of running machines


  # @author jhou@redhat.com
  @admin
  Scenario Outline: Metrics is exposed on https
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :token clipboard

    When I run the :exec admin command with:
      | n                | openshift-monitoring                                           |
      | pod              | prometheus-k8s-0                                               |
      | c                | prometheus                                                     |
      | oc_opts_end      |                                                                |
      | exec_command     | sh                                                             |
      | exec_command_arg | -c                                                             |
      | exec_command_arg | curl -v -s -k -H "Authorization: Bearer <%= cb.token %>" <url> |
    Then the step should succeed

    Examples:
      | url                                                                          |
      | https://machine-api-operator.openshift-machine-api.svc:8443/metrics          | # @case_id OCP-25652
      | https://cluster-autoscaler-operator.openshift-machine-api.svc:9192/metrics   | # @case_id OCP-26111
      | https://machine-approver.openshift-cluster-machine-approver.svc:9192/metrics | # @case_id OCP-26102


  # @author miyadav@redhat.com
  # @case_id OCP-27627

 @admin
 Scenario: Verify all machine instance-state should be consistent with their providerStats.instanceState
   Given I have an IPI deployment
   When I run the :get admin command with:
      | resource  | machines                                                                                              |
      | namespace | openshift-machine-api                                                                                 |
      | o         | jsonpath='{range .items[*]}{.metadata.annotations}{.status.providerStatus.instanceState}{"/\\n"}{end}'|

   And evaluation of `@result[:response].split(":")` is stored in the :console_output_array clipboard

   #Evaluating Result for each line
   When I repeat the following steps for each :console_output in cb.console_output_array:
   """
   And evaluation of `cb.console_output_array.pop.split("]")[0]` is stored in the :provider_status clipboard
   And evaluation of `cb.console_output_array.pop.split(":").pop.split("]")[1].split("/")[0]` is stored in the :instance_state clipboard
   Then the expression should be true> cb.provider_status == cb.instance_state
   """
  Then the step should succeed

