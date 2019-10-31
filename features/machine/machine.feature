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
    And I store all machinesets to the :machinesets clipboard

    Given evaluation of `machine_set.desired_replicas` is stored in the :replicas_original clipboard
    And evaluation of `machine_set.desired_replicas.to_i + 1` is stored in the :replicas_expected clipboard
    And I store the number of machines in the :num_machines_original clipboard

    # scale up
    When I run the :scale admin command with:
      | resource | machineset                  |
      | name     | <%= machine_set.name %>     |
      | replicas | <%= cb.replicas_expected %> |
      | n        | openshift-machine-api       |
    Then the step should succeed

    # register clean-up just in case of failure
    Given I register clean-up steps:
    """
    When I run the :scale admin command with:
      | resource | machineset                  |
      | name     | <%= machine_set.name %>     |
      | replicas | <%= cb.replicas_original %> |
      | n        | openshift-machine-api       |
    Then the step should succeed
    """

    # num of machines should increase
    And I wait for the steps to pass:
    """
    Given I store the number of machines in the :num_machines_current clipboard
    Then the expression should be true> cb.num_machines_current.to_i == cb.num_machines_original.to_i + 1
    """

    Given I store the last provisioned machine in the :new_machine clipboard
    And I wait for the node of machine named "<%= cb.new_machine %>" to appear

    # new node should be ready
    And admin waits for the "<%= cb.new_node %>" node to become ready up to 600 seconds

    # scale down
    And I run the :scale admin command with:
      | resource | machineset                  |
      | name     | <%= machine_set.name %>     |
      | replicas | <%= cb.replicas_original %> |
      | n        | openshift-machine-api       |
    Then the step should succeed

    # node should be deleted
    Given I switch to cluster admin pseudo user
    Then I wait for the resource "node" named "<%= cb.new_node %>" to disappear within 600 seconds

  # @author jhou@redhat.com
  # @case_id OCP-25652
  @admin
  Scenario: MAO metrics is exposed on https
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.first).token` is stored in the :token clipboard

    When I run the :exec admin command with:
      | n                | openshift-monitoring                                                                                                         |
      | pod              | prometheus-k8s-0                                                                                                             |
      | c                | prometheus                                                                                                                   |
      | oc_opts_end      |                                                                                                                              |
      | exec_command     | sh                                                                                                                           |
      | exec_command_arg | -c                                                                                                                           |
      | exec_command_arg | curl -v -s -k -H "Authorization: Bearer <%= cb.token %>" https://machine-api-operator.openshift-machine-api.svc:8443/metrics |
    Then the step should succeed
