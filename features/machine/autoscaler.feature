Feature: Cluster Autoscaler Tests

  # @author jhou@redhat.com
  # @case_id OCP-28108
  @admin
  @aro
  @destructive
  @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @upgrade-sanity
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @critical
  @level0
  Scenario: OCP-28108:ClusterInfrastructure Cluster should automatically scale up and scale down with clusterautoscaler deployed
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-28108"

    # Create clusterautoscaler
    Given I obtain test data file "cloud/cluster-autoscaler.yml"
    When I run the :create admin command with:
      | f | cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pod becomes ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

    # Create machineautoscaler
    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                                      |
      | ["spec"]["minReplicas"]            | 1                                            |
      | ["spec"]["maxReplicas"]            | 3                                            |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set_machine_openshift_io.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario

    # Create workload
    Given I obtain test data file "cloud/autoscaler-auto-tmpl.yml"
    When I run the :create admin command with:
      | f | autoscaler-auto-tmpl.yml |
    Then the step should succeed
    And admin ensures "workload" job is deleted from the "openshift-machine-api" project after scenario

    # Verify machineset has scaled
    Given I wait up to 960 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 1200 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

    # Check autoscaler taints are deleted when min node is reached
    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).node_name` is stored in the :noderef_name clipboard
    When I run the :describe admin command with:
      | resource | node                  |
      | name     | <%= cb.noderef_name%> |
    Then the step should succeed
    And the output should not contain:
      | DeletionCandidateOfClusterAutoscaler |
      | ToBeDeletedByClusterAutoscaler       |

  # @author zhsun@redhat.com
  # @case_id OCP-21516
  @admin
  @destructive
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @critical
  @hypershift-hosted
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  Scenario: OCP-21516:ClusterInfrastructure Cao listens and deploys cluster-autoscaler based on ClusterAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project

    Given I obtain test data file "cloud/cluster-autoscaler.yml"
    When I run the :create admin command with:
      | f | cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pod becomes ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

  # @author zhsun@redhat.com
  # @case_id OCP-21517
  @admin
  @destructive
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @critical
  @hypershift-hosted
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  Scenario: OCP-21517:ClusterInfrastructure CAO listens and annotations machineSets based on MachineAutoscaler resource
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-21517"
    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                                      |
      | ["spec"]["minReplicas"]            | 1                                            |
      | ["spec"]["maxReplicas"]            | 3                                            |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set_machine_openshift_io.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario
    When I run the :get admin command with:
      | resource      | machineautoscaler |
      | resource_name | maotest           |
    Then the step succeeded
    Then the expression should be true> machine_set_machine_openshift_io.annotation("machine.openshift.io/cluster-api-autoscaler-node-group-min-size", cached: false) == "1"
    Then the expression should be true> machine_set_machine_openshift_io.annotation("machine.openshift.io/cluster-api-autoscaler-node-group-max-size", cached: false) == "3"

    When I run the :delete admin command with:
      | object_type       | machineautoscaler |
      | object_name_or_id | maotest           |
    Then the step succeeded
    When I run the :describe admin command with:
      | resource | machinesets.machine.openshift.io             |
      | name     | <%= machine_set_machine_openshift_io.name %> |
    Then the step should succeed
    And the output should not match "autoscaling.openshift.io/machineautoscaler"

  # @author zhsun@redhat.com
  # @case_id OCP-22102
  @admin
  @aro
  @destructive
  @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-22102:ClusterInfrastructure Update machineAutoscaler to reference a different MachineSet
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-22102"
    And evaluation of `machine_set_machine_openshift_io.name` is stored in the :machineset_clone_22102 clipboard
    Given I clone a machineset and name it "machineset-clone-22102-2"
    And evaluation of `machine_set_machine_openshift_io.name` is stored in the :machineset_clone_22102_2 clipboard

    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest0                         |
      | ["spec"]["scaleTargetRef"]["name"] | <%= cb.machineset_clone_22102 %> |
    Then the step should succeed
    And admin ensures "maotest0" machineautoscaler is deleted after scenario
    When I run the :patch admin command with:
      | resource      | machineautoscaler                                                         |
      | resource_name | maotest0                                                                  |
      | p             | {"spec":{"scaleTargetRef":{"name":"<%= cb.machineset_clone_22102_2 %>"}}} |
      | type          | merge                                                                     |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource | machineautoscaler |
      | name     | maotest0          |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machineset_clone_22102_2 %>"
    When I run the :describe admin command with:
      | resource | machinesets.machine.openshift.io |
      | name     | <%= cb.machineset_clone_22102 %> |
    Then the step should succeed
    And the output should not match "autoscaling.openshift.io/machineautoscaler"
    When I run the :describe admin command with:
      | resource | machinesets.machine.openshift.io   |
      | name     | <%= cb.machineset_clone_22102_2 %> |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/maotest0"

    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest1                         |
      | ["spec"]["scaleTargetRef"]["name"] | <%= cb.machineset_clone_22102 %> |
    Then the step should succeed
    And admin ensures "maotest1" machineautoscaler is deleted after scenario
    When I run the :patch admin command with:
      | resource      | machineautoscaler                                                       |
      | resource_name | maotest0                                                                |
      | p             | {"spec":{"scaleTargetRef":{"name":"<%= cb.machineset_clone_22102 %>"}}} |
      | type          | merge                                                                   |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource | machineautoscaler |
      | name     | maotest0          |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.machineset_clone_22102 %>"
    When I run the :describe admin command with:
      | resource | machinesets.machine.openshift.io |
      | name     | <%= cb.machineset_clone_22102 %> |
    Then the step should succeed
    And the output should match "Annotations:\s+autoscaling.openshift.io/machineautoscaler: openshift-machine-api/maotest1"
    When I run the :describe admin command with:
      | resource | machinesets.machine.openshift.io   |
      | name     | <%= cb.machineset_clone_22102_2 %> |
    Then the step should succeed
    And the output should not match "autoscaling.openshift.io/machineautoscaler"

  # @author zhsun@redhat.com
  # @case_id OCP-23745
  @admin
  @aro
  @destructive
  @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-23745:ClusterInfrastructure Machineautoscaler can be deleted when its referenced machineset does not exist
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest |
      | ["spec"]["minReplicas"]            | 1       |
      | ["spec"]["maxReplicas"]            | 3       |
      | ["spec"]["scaleTargetRef"]["name"] | invalid |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted
