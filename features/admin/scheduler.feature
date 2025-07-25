Feature: Scheduler related scenarios

  # @author wmeng@redhat.com
  # @case_id OCP-14582
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @level0
  Scenario: OCP-14582:Workloads When no scheduler name is supplied, the pod is automatically scheduled using the default-scheduler
    Given I have a project
    Given I obtain test data file "scheduler/multiple-schedulers/pod-no-scheduler.yaml"
    When I run the :create client command with:
      | f | pod-no-scheduler.yaml |
    Then the step should succeed
    Given the pod named "no-scheduler" becomes ready
    When I run the :describe client command with:
      | resource | pods         |
      | name     | no-scheduler |
    Then the output should match:
      | Status:\\s+Running |
      | default-scheduler  |

