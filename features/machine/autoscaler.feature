Feature: Cluster Autoscaler Tests

  # @author jhou@redhat.com
  # @case_id OCP-28108
  @admin
  @destructive
  Scenario: Cluster should automatically scale up and scale down with clusterautoscaler deployed
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I clone a machineset named "machineset-clone"

    # Create clusterautoscaler
    Given I use the "openshift-machine-api" project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pods become ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

    # Create machineautoscaler
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                 |
      | ["spec"]["minReplicas"]            | 1                       |
      | ["spec"]["maxReplicas"]            | 3                       |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario

    # Create workload
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/autoscaler-auto-tmpl.yml |
    Then the step should succeed

    # Verify machineset has scaled
    Given I wait up to 60 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 120 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

  # @author zhsun@redhat.com
  # @case_id OCP-21516
  @admin
  @destructive
  Scenario: Cao listens and deploys cluster-autoscaler based on ClusterAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pods become ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

  # @author zhsun@redhat.com
  # @case_id OCP-21517
  @admin
  @destructive
  Scenario: CAO listens and annotations machineSets based on MachineAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I use the "openshift-machine-api" project
    Given I clone a machineset named "machineset-clone"
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                 |
      | ["spec"]["minReplicas"]            | 1                       |
      | ["spec"]["maxReplicas"]            | 3                       |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario
    When I run the :get admin command with:
      | resource      | machineautoscaler |
      | resource_name | maotest           |
    Then the step succeeded
    Then the expression should be true> machine_set.annotation("machine.openshift.io/cluster-api-autoscaler-node-group-min-size", cached: false) == "1"
    Then the expression should be true> machine_set.annotation("machine.openshift.io/cluster-api-autoscaler-node-group-max-size", cached: false) == "3"

    When I run the :delete admin command with:
      | object_type       | machineautoscaler |
      | object_name_or_id | maotest           |
    Then the step succeeded
    When I run the :describe admin command with:
      | resource | machineset              |
      | name     | <%= machine_set.name %> |
    Then the step should succeed
    And the output should match "Annotations:\s+<none>"

  # @author zhsun@redhat.com
  # @case_id OCP-22102
  @admin
  @destructive
  Scenario: Update machineAutoscaler to reference a different MachineSet
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I use the "openshift-machine-api" project
    Given I clone a machineset named "machineset-clone0"
    And evaluation of `machine_set.name` is stored in the :machineset_clone0_name clipboard
    Given I clone a machineset named "machineset-clone1"
    And evaluation of `machine_set.name` is stored in the :machineset_clone1_name clipboard

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest0                         |
      | ["spec"]["scaleTargetRef"]["name"] | <%= cb.machineset_clone0_name %> |
    Then the step should succeed
    And admin ensures "maotest0" machineautoscaler is deleted after scenario
    When I run the :patch admin command with:
      | resource      | machineautoscaler                                                       |
      | resource_name | maotest0                                                                |
      | p             | {"spec":{"scaleTargetRef":{"name":"<%= cb.machineset_clone1_name %>"}}} |
      | type          | merge                                                                   |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource | machineautoscaler |
      | name     | maotest0          |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machineset_clone1_name %>"
    When I run the :describe admin command with:
      | resource | machineset                       |
      | name     | <%= cb.machineset_clone0_name %> |
    Then the step should succeed
    And the output should match "Annotations:\s+<none>"
    When I run the :describe admin command with:
      | resource | machineset                       |
      | name     | <%= cb.machineset_clone1_name %> |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/maotest0"

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest1                         |
      | ["spec"]["scaleTargetRef"]["name"] | <%= cb.machineset_clone0_name %> |
    Then the step should succeed
    And admin ensures "maotest1" machineautoscaler is deleted after scenario
    When I run the :patch admin command with:
      | resource      | machineautoscaler                                                       |
      | resource_name | maotest0                                                                |
      | p             | {"spec":{"scaleTargetRef":{"name":"<%= cb.machineset_clone0_name %>"}}} |
      | type          | merge                                                                   |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource | machineautoscaler |
      | name     | maotest0          |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machineset_clone0_name %>"
    When I run the :describe admin command with:
      | resource | machineset                       |
      | name     | <%= cb.machineset_clone0_name %> |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/maotest1"
    When I run the :describe admin command with:
      | resource | machineset                       |
      | name     | <%= cb.machineset_clone1_name %> |
    Then the step should succeed
    And the output should match "Annotations:\s+<none>"

