Feature: fips enabled verification for upgrade
  # @author xiyuan@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: FIPS mode checking command works for a cluster with fip mode on
    #precondition check
    When I run the :get admin command with:
      | resource | mc |
    Then the step should succeed
    And the output should contain:
      | 99-master-fips |
      | 99-worker-fips |
    
    #check whether fips enabled for master node
    Given I store the masters in the :masters clipboard
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
    And the output should contain:
      | RHCOS FIPS mode installation complete |

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
  Scenario: FIPS mode checking command works for a cluster with fip mode on
    #precondition check
    When I run the :get admin command with:
      | resource | mc |
    Then the step should succeed
    And the output should contain:
      | 99-master-fips |
      | 99-worker-fips |

    #check whether fips enabled for master node
    Given I store the masters in the :masters clipboard
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
    And the output should contain:
      | RHCOS FIPS mode installation complete |

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
