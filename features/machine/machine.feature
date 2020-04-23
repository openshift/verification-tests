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

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I clone a machineset named "machineset-clone-25436"

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
    When I run the :describe admin command with:
      | resource      | machine                                |
      | name          | <%= cb.machine %>                      |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And the output should match "Provider ID:\s+<%= cb.providerID %>"

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
    And I clone a machineset named "machineset-clone-publiciptrue"

    Then I run the :get admin command with:
     | resource      | machineset                    |
     | resource_name | machineset-clone-publiciptrue |
     | namespace     | openshift-machine-api         |
     | o             | yaml                          |
    And I save the output to file> new_machineset.yaml

    And I replace lines in "new_machineset.yaml":
     | publicIp: null| publicIp: true |
    Then the step should succeed

    When I run the :replace admin command with:
     | f | new_machineset.yaml |
    And the output should match:
     | [Rr]eplaced |

    Given I scale the machineset to +2
    Then the machineset should have expected number of running machines

  # @author zhsun@redhat.com
  @admin
  @destructive
  Scenario Outline: Machineset should have relevant annotations to support scale from/to zero
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And I pick a random machineset to scale

    Given I run the :get admin command with:
      | resource      | machineset              |
      | resource_name | <%= machine_set.name %> |
      | o             | yaml                    |
    Then the step should succeed
    And I save the output to file> machineset.yaml

    # Create a machineset with a valid instanceType
    And I replace content in "machineset.yaml":
      | <%= machine_set.name %> | <machineset_name>-valid |
      | <re_type_field>         | <valid_value>           |
      | /replicas:.*/           | replicas: 1             |

    When I run the :create admin command with:
      | f | machineset.yaml |
    Then the step should succeed
    And admin ensures "<machineset_name>-valid" machineset is deleted after scenario

    When I run the :annotate admin command with:
      | resource     | machineset               |
      | resourcename | <machineset_name>-valid  |
      | overwrite    | true                     |
      | keyval       | new=new                  |
    Then the step should succeed

    When I run the :describe admin command with:
      | resource | machineset              |
      | name     | <machineset_name>-valid |
    Then the step should succeed
    And the output should contain:
      | machine.openshift.io/memoryMb: |
      | machine.openshift.io/vCPU:     |
      | new:                           |

    # Create a machineset with an invalid instanceType
    And I replace content in "machineset.yaml":
      | <%= machine_set.name %> | <machineset_name>-invalid |
      | <re_type_field>         | <invalid_value>           |
      | /replicas:.*/           | replicas: 1               |

    When I run the :create admin command with:
      | f | machineset.yaml |
    Then the step should succeed
    And admin ensures "<machineset_name>-invalid" machineset is deleted after scenario

    Given 1 pods become ready with labels:
      | api=clusterapi,k8s-app=controller |
    And I wait for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>    | 
      | c             | machine-controller |
    Then the step should succeed
    And the output should match:
      | <machineset_name>-invalid.*ReconcileError |
    """

    # Create a machineset with no instanceType set
    And I replace content in "machineset.yaml":
      | <%= machine_set.name %> | <machineset_name>-no |
      | <re_type_field>         | <no_value>           |
      | /replicas:.*/           | replicas: 1          |

    When I run the :create admin command with:
      | f | machineset.yaml |
    Then the step should succeed
    And admin ensures "<machineset_name>-no" machineset is deleted after scenario
    And I wait for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>    | 
      | c             | machine-controller | 
    Then the step should succeed
    And the output should match:
      | <machineset_name>-no.*ReconcileError |
    """

    Examples:
      | re_type_field     | valid_value                | invalid_value         | no_value      | machineset_name  |
      | /machineType:.*/  | machineType: n1-standard-2 | machineType: invalid  | machineType:  | machineset-28778 | # @case_id OCP-28778
      | /vmSize:.*/       | vmSize: Standard_D2s_v3    | vmSize: invalid       | vmSize:       | machineset-28876 | # @case_id OCP-28876
      | /instanceType:.*/ | instanceType: m4.large     | instanceType: invalid | instanceType: | machineset-28875 | # @case_id OCP-28875 
  
  # @author miyadav@redhat.com
  # @case_id OCP-24363
  @admin
  @destructive
  Scenario: [MAO] Reconciling machine taints with nodes
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    
    Given I clone a machineset named "machineset-24363"
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

