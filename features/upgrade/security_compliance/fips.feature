Feature: fips enabled verification for upgrade

  # @author xiyuan@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @fips
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @hypershift-hosted
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @level0
  Scenario: FIPS mode checking command works for a cluster with fip mode on - prepare
    Given fips is enabled

    #check whether fips enabled for master node
    When I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | update-crypto-policies --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | cat /etc/system-fips |
    Then the step should succeed
    And the output should match:
      | FIPS mod.*installation complete |
    """

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I use the "<%= cb.workers[0].name %>" node
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | cat /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |
    """

  # @author xiyuan@redhat.com
  # @case_id OCP-25821
  @upgrade-check
  @users=upuser1,upuser2
  @fips
  @admin
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @level0
  Scenario: FIPS mode checking command works for a cluster with fip mode on
    Given fips is enabled
    #check whether fips enabled for master node
    When I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | update-crypto-policies --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | cat /etc/system-fips |
    Then the step should succeed
    And the output should match:
      | FIPS mod.*installation complete |
    """

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I use the "<%= cb.workers[0].name %>" node
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    """
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run commands on the host:
      | cat /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |
    """
