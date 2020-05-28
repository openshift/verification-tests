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
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-25436"

    Given I scale the machineset to +2
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

  # @author zhsun@redhat.com
  # @case_id OCP-25608
  @admin
  @destructive
  Scenario: Machine should have immutable field providerID and nodeRef
    Given I have an IPI deployment
    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine(cb.machine).node_name` is stored in the :nodeRef_name clipboard
    And evaluation of `machine(cb.machine).provider_id` is stored in the :providerID clipboard

    When I run the :patch admin command with:
      | resource      | machine                                |
      | resource_name | <%= cb.machine %>                      |
      | p             | {"status":{"nodeRef":{"name":"test"}}} |
      | type          | merge                                  |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource      | machine                                |
      | name          | <%= cb.machine %>                      |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.nodeRef_name %>"

    When I run the :patch admin command with:
      | resource      | machine                                |
      | resource_name | <%= cb.machine %>                      |
      | p             | {"spec":{"providerID":"invalid"}}      |
      | type          | merge                                  |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource      | machine                                |
      | name          | <%= cb.machine %>                      |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And the output should match "Provider ID:\s+<%= cb.providerID %>"
    """

  # @author miyadav@redhat.com
  # @case_id OCP-27627
  @admin
  Scenario: Verify all machine instance-state should be consistent with their providerStats.instanceState
    Given I have an IPI deployment
    And evaluation of `BushSlicer::Machine.list(user: admin, project: project('openshift-machine-api'))` is stored in the :machines clipboard
    Then the expression should be true> cb.machines.select{|m|m.instance_state == m.annotation_instance_state}.count == cb.machines.count

  # @author miyadav@redhat.com
  # @case_id OCP-27609
  @admin
  @destructive
  Scenario: Scaling a machineset with providerSpec.publicIp set to true
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-27609"
    Then as admin I successfully merge patch resource "machineset/machineset-clone-27609" with:
      | {"spec":{"template": {"spec":{"providerSpec":{"value":{"publicIP": true}}}}}} |
    And I scale the machineset to +2
    Then the machineset should have expected number of running machines

  # @author miyadav@redhat.com
  # @case_id OCP-24363
  @admin
  @destructive
  Scenario: [MAO] Reconciling machine taints with nodes
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-24363"
    And evaluation of `machine_set.machines.first.node_name` is stored in the :noderef_name clipboard
    And evaluation of `machine_set.machines.first.name` is stored in the :machine_name clipboard

    Given I saved following keys to list in :taintsid clipboard:
      | {"spec":{"taints": [{"effect": "NoExecute","key": "role","value": "master"}]}}  | |
      | {"spec":{"taints": [{"effect": "NoSchedule","key": "role","value": "master"}]}} | |

    And I use the "openshift-machine-api" project
    Then I repeat the following steps for each :id in cb.taintsid:
    """
    Given as admin I successfully merge patch resource "machine/<%= cb.machine_name %>" with:
      | #{cb.id} |
    Then the step should succeed
    """
    When I run the :describe admin command with:
      | resource | node                 |
      | name     |<%= cb.noderef_name %>|
    Then the output should contain:
      | role=master:NoExecute |
      | role=master:NoSchedule|

  # @author zhsun@redhat.com
  @admin
  @destructive
  Scenario Outline: Required configuration should be added to the ProviderSpec to enable spot instances
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And admin ensures machine number is restored after scenario

    #Create a spot machineset
    Given I use the "openshift-machine-api" project
    Given I create a spot instance machineset and name it "<machineset_name>" on <iaas_type>
    And evaluation of `machine_set.machines.first.node_name` is stored in the :noderef_name clipboard
    And evaluation of `machine_set.machines.first.name` is stored in the :machine_name clipboard

    #Check machine and node were labelled as an `interruptible-instance`
    When I run the :describe admin command with:
      | resource | machine                |
      | name     | <%= cb.machine_name %> |
    Then the step should succeed
    And the output should match "machine.openshift.io/interruptible-instance"
    When I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.noderef_name %> |
    Then the step should succeed
    And the output should match "machine.openshift.io/interruptible-instance="
    And "machine-api-termination-handler" daemonset becomes ready in the "openshift-machine-api" project
    And 1 pods become ready with labels:
      | k8s-app=termination-handler |

    Examples:
      | iaas_type | machineset_name  |
      | aws       | machineset-29199 | # @case_id OCP-29199

