Feature: MachineHealthCheck Test Scenarios

  # @author jhou@redhat.com
  # @case_id OCP-25897
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-25897:ClusterInfrastructure Remediation should be applied when the unhealthyCondition 'Ready' is met
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-25897"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                            |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>" machine_health_check_machine_openshift_io is deleted after scenario

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
      | drain successful for machine "<%= machine_machine_openshift_io.name %>" |

  # @author jhou@redhat.com
  # @case_id OCP-26311
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-26311:ClusterInfrastructure Create a machinehealthcheck when there is already an unhealthy machine
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-26311"

    # Create unhealthyCondition before createing a MHC
    Given I create the 'Ready' unhealthyCondition

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                            |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>" machine_health_check_machine_openshift_io is deleted after scenario

    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25734
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-25734:ClusterInfrastructure Create multiple MHCs to monitor same machineset
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-25734"

    # Create MHCs
    Given I run the steps 2 times:
    """
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                                      |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %>-#{ cb.i } |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>            |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>               |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>-#{ cb.i }" machine_health_check_machine_openshift_io is deleted after scenario
    """

    # Create unhealthyCondition before createing a MHC
    When I create the 'Ready' unhealthyCondition
    Then the machine should be remediated

  # @author jhou@redhat.com
  # @case_id OCP-25691
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-25691:ClusterInfrastructure Use "maxUnhealthy" to prevent automated remediation
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario
    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-25691"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                              |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %>-1 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 0                                                  |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>-1" machine_health_check_machine_openshift_io is deleted after scenario
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                              |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %>-2 |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>    |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>       |
      | ["spec"]["maxUnhealthy"]                                                           | 90%                                                |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>-2" machine_health_check_machine_openshift_io is deleted after scenario

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
      | mhc-<%= machine_set_machine_openshift_io.name %>-1: total targets: 1,  maxUnhealthy: 0, unhealthy: 1. Short-circuiting remediation   |
      | mhc-<%= machine_set_machine_openshift_io.name %>-2: total targets: 1,  maxUnhealthy: 90%, unhealthy: 1. Short-circuiting remediation |
    """
    When I run the :describe admin command with:
      | resource | machinehealthchecks.machine.openshift.io/mhc-<%= machine_set_machine_openshift_io.name %>-2 |
    Then the output should match:
      | Type.*RemediationAllowed |

  # @author miyadav@redhat.com
  # @case_id OCP-28718
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  Scenario: OCP-28718:ClusterInfrastructure Machine Node startup timeout should be configurable
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-28718"

    # Create MHC with configurable node startup timeout
    Given I obtain test data file "cloud/mhc/mhc_configurabletimeout.yaml"
    When I run oc create over "mhc_configurabletimeout.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                            |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>     |
      | ["spec"]["nodeStartupTimeout" ]                                                    | 15m                                              |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>" machine_health_check_machine_openshift_io is deleted after scenario

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
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-25727:ClusterInfrastructure Remediation should be applied when machine has nodeRef but node is deleted
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-25727"

    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                            |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>     |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>" machine_health_check_machine_openshift_io is deleted after scenario

    Given I store the last provisioned machine in the :new_machine clipboard
    Given admin ensures "<%= machine_machine_openshift_io(cb.new_machine).node_name %>" node is deleted
    Then the machine named "<%= cb.new_machine %>" should be remediated

  # @author miyadav@redhat.com
  # @case_id OCP-29857
  @admin
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  Scenario: OCP-29857:ClusterInfrastructure MaxUnhealthy should not allow malformed values
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    Then I use the "openshift-machine-api" project
    And evaluation of `BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project('openshift-machine-api'))` is stored in the :machines clipboard

    # Create MHC with malformed unhealthy nodes value and empty selectors
    Given I obtain test data file "cloud/mhc/mhc_malformed.yaml"
    When I run oc create over "mhc_malformed.yaml" replacing paths:
      | n  | openshift-machine-api |
    Then the step should fail 
    And the output should contain:
      | spec.maxUnhealthy in body should match '^((100|[0-9]{1,2})%|[0-9]+)$' | #This covers OCP-29062 - empty selectors watches all machines in cluster

  # @author miyadav@redhat.com
  # @case_id OCP-28859
  @admin
  @aro
  @destructive
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-28859:ClusterInfrastructure MHC MaxUnhealthy string value should be checked for '%' symbol
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    And evaluation of `infrastructure("cluster").infra_name` is stored in the :infraName clipboard
    Given I clone a machineset and name it "<%= cb.infraName %>-28859"

    # Create MHC
    Given I obtain test data file "cloud/mhc/mhc1.yaml"
    When I run oc create over "mhc1.yaml" replacing paths:
      | n                                                                                  | openshift-machine-api                            |
      | ["metadata"]["name"]                                                               | mhc-<%= machine_set_machine_openshift_io.name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]    | <%= machine_set_machine_openshift_io.cluster %>  |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"] | <%= machine_set_machine_openshift_io.name %>     |
      | ["spec"]["maxUnhealthy"]                                                           | "1%"                                             |
    Then the step should succeed
    And I ensure "mhc-<%= machine_set_machine_openshift_io.name %>" machine_health_check_machine_openshift_io is deleted after scenario

    Then a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |

    Given I create the 'Ready' unhealthyCondition

    And I wait up to 600 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>                |
      | c             | machine-healthcheck-controller |
    Then the output should contain:
      | mhc-<%= machine_set_machine_openshift_io.name %>: total targets: 1,  maxUnhealthy: 1%, unhealthy: 1. Short-circuiting remediation |
    """

  # @author miyadav@redhat.com
  # @case_id OCP-33714
  @admin
  @osd_ccs @aro
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  Scenario: OCP-33714:ClusterInfrastructure Leverage OpenAPI validation within MHC
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
  @osd_ccs @aro
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  Scenario: OCP-34095:ClusterInfrastructure timeout field without units(h,m,s) shoud not be allowed to be stored
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
      | timeout: Invalid value: ".*": spec.unhealthyConditions.*.timeout |
    """
