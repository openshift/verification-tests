Feature: Seccomp part of SCC policy should be kept and working after upgrade

  # @author sunilc@redhat.com
  @upgrade-prepare
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @disconnected @connected
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
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Seccomp part of SCC policy should be kept and working after upgrade
    Given I switch to cluster admin pseudo user
    Given admin checks that the "seccomp" scc exists
