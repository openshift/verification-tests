Feature: Node components upgrade tests

  # @author minmli@redhat.com
  @upgrade-prepare
  @admin
  @long-duration
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @disconnected @connected
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: Make sure nodeConfig is not changed after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :label admin command with:
      | resource | machineconfigpool         |
      | name     | master                    |
      | key_val  | custom-kubelet=small-pods |
    Then the step should succeed
    Given I obtain test data file "customresource/custom_kubelet.yaml"
    When I run the :create client command with:
      | f | custom_kubelet.yaml |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | machineconfigpool |
      | resource_name | master            |
    Then the output should match:
      | .*False\\s+True\\s+False |
    """
    And I wait up to 1980 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | machineconfigpool |
      | resource_name | master            |
    Then the output should match:
      | .*True\\s+False\\s+False |
    """
    Given I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | cat /etc/kubernetes/kubelet.conf |
    Then the step should succeed
    And the output should contain:
      | "imageMinimumGCAge": "5m0s"       |
      | "imageGCHighThresholdPercent": 80 |
      | "maxPods": 240                    |

  # @author minmli@redhat.com
  # @case_id OCP-13022
  @upgrade-check
  @admin
  @long-duration
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: Make sure nodeConfig is not changed after upgrade
    Given I switch to cluster admin pseudo user
    When I run the :get admin command with:
      | resource      | kubeletconfig  |
      | resource_name | custom-kubelet |
    Then the step should succeed
    And the output should contain:
      | custom-kubelet |
    Given I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | cat /etc/kubernetes/kubelet.conf |
    Then the step should succeed
    And the output should contain:
      | "imageMinimumGCAge": "5m0s"       |
      | "imageGCHighThresholdPercent": 80 |
      | "maxPods": 240                    |
