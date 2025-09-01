Feature: UPI GCP Tests

  # @author zhsun@redhat.com
  # @case_id OCP-34697
  @admin
  @destructive
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @gcp-upi
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-34697:ClusterInfrastructure MachineSets in GCP should create Machines in a Shared (XPN) VPC environment
    Given I have an UPI deployment and machinesets are enabled

  # @author zhsun@redhat.com
  # @case_id OCP-25034
  @admin
  @destructive
  @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @gcp-upi
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-25034:ClusterInfrastructure GCP Scaling OCP Cluster on UPI
    Given I have an UPI deployment and machinesets are enabled
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-25034"

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
      | ["metadata"]["name"]               | maotest                 |
      | ["spec"]["minReplicas"]            | 1                       |
      | ["spec"]["maxReplicas"]            | 3                       |
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
    Given I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines
