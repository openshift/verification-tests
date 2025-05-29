Feature: Seccomp part of SCC policy should be kept and working after upgrade

  # @author sunilc@redhat.com
  @upgrade-prepare
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @hypershift-hosted
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario: Seccomp part of SCC policy should be kept and working after upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given I obtain test data file "node/scc.yaml"
    When I run the :create client command with:
      | f | scc.yaml |
    Then the step should succeed

  # @author sunilc@redhat.com
  # @case_id OCP-13065
  @upgrade-check
  @admin
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: Seccomp part of SCC policy should be kept and working after upgrade
    Given I switch to cluster admin pseudo user
    Given admin checks that the "seccomp" scc exists
