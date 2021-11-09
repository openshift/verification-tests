Feature: fips enabled verification for upgrade
  # @author xiyuan@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  @4.8 @4.10 @4.9
  @azure-ipi @openstack-ipi @baremetal-ipi @vsphere-ipi @gcp-ipi @aws-ipi
  @azure-upi @aws-upi @openstack-upi @vsphere-upi @gcp-upi
  Scenario: FIPS mode checking command works for a cluster with fip mode on - prepare
    Given fips is enabled

    #check whether fips enabled for master node
    When I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | update-crypto-policies --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When I run commands on the host:
      | cat /etc/system-fips |
    Then the step should succeed
    And the output should match:
      | FIPS mod.*installation complete |

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I use the "<%= cb.workers[0].name %>" node
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When I run commands on the host:
      | cat /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |

  # @author xiyuan@redhat.com
  # @case_id OCP-25821
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  @4.8 @4.10 @4.9
  @azure-ipi @openstack-ipi @baremetal-ipi @vsphere-ipi @gcp-ipi @aws-ipi
  @azure-upi @aws-upi @openstack-upi @vsphere-upi @gcp-upi
  Scenario: FIPS mode checking command works for a cluster with fip mode on
    Given fips is enabled

    #check whether fips enabled for master node
    When I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | update-crypto-policies --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When I run commands on the host:
      | cat /etc/system-fips |
    Then the step should succeed
    And the output should match:
      | FIPS mod.*installation complete |

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I use the "<%= cb.workers[0].name %>" node
    When I run commands on the host:
      | sysctl crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When I run commands on the host:
      | cat /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |
