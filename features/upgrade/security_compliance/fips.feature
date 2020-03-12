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
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | sc-upgrade |
    Then the step should succeed
    Given I store the masters in the :masters clipboard
    When I run the :debug admin command with:
      | resource | no/<%= cb.masters[0].name %> |
      | dry_run  | true                         |
      | o        | yaml                         |
    Then the step should succeed
    And I save the output to file>debug_pod.yaml
    When I use the "sc-upgrade" project
    And I replace lines in "debug_pod.yaml":
      | /name.*debug/                          | name: mypod           |
      | /namespace: .*/                        | namespace: sc-upgrade |
      | registry.redhat.io/rhel7/support-tools | aosqe/hello-openshift |
    Then the step should succeed
    When I run the :create admin command with:
      | f | debug_pod.yaml |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    When I use the "sc-upgrade" project 
    And the pod named "mypod" becomes ready

    When admin executes on the pod:
      | chroot | /host | update-crypto-policies | --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    When admin executes on the pod:
      | chroot | /host | sysctl | crypto.fips_enabled | 
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When admin executes on the pod:
      | chroot | /host | cat | /etc/system-fips |
    Then the step should succeed
    And the output should contain:
      | RHCOS FIPS mode installation complete |

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I replace lines in "debug_pod.yaml":
      | name: mypod               | name: mypod2              |
      | <%= cb.masters[0].name %> | <%= cb.workers[0].name %> |
    Then the step should succeed
    When I run the :create admin command with:
      | f | debug_pod.yaml |
    Then the step should succeed
    And the pod named "mypod2" becomes ready

    When admin executes on the pod:
      | chroot | /host | sysctl | crypto.fips_enabled |  
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When admin executes on the pod:
      | chroot | /host | cat | /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |

    Given admin ensures "mypod" pod is deleted
    And admin ensures "mypod2" pod is deleted

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

    #check whether fips enabled for worker node
    Given I switch to cluster admin pseudo user
    When I use the "sc-upgrade" project
    Given I store the masters in the :masters clipboard
    When I run the :debug admin command with:
      | resource | no/<%= cb.masters[0].name %> |
      | dry_run  | true                         |
      | o        | yaml                         |
    Then the step should succeed
    And I save the output to file>debug_pod.yaml
    When I use the "sc-upgrade" project
    And I replace lines in "debug_pod.yaml":
      | /name.*debug/                          | name: mypod           |
      | /namespace: .*/                        | namespace: sc-upgrade |
      | registry.redhat.io/rhel7/support-tools | aosqe/hello-openshift |
    Then the step should succeed
    When I run the :create admin command with:
      | f | debug_pod.yaml |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    When I use the "sc-upgrade" project
    And the pod named "mypod" becomes ready

    When admin executes on the pod:
      | chroot | /host | update-crypto-policies | --show |
    Then the step should succeed
    And the output should match:
      | FIPS |
    When admin executes on the pod:
      | chroot | /host | sysctl | crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When admin executes on the pod:
      | chroot | /host | cat | /etc/system-fips |
    Then the step should succeed
    And the output should contain:
      | RHCOS FIPS mode installation complete |

    # check whether fips mode enabled or not for worker node
    Given I store the workers in the :workers clipboard
    And I replace lines in "debug_pod.yaml":
      | name: mypod               | name: mypod2              |
      | <%= cb.masters[0].name %> | <%= cb.workers[0].name %> |
    Then the step should succeed
    When I run the :create admin command with:
      | f | debug_pod.yaml |
    Then the step should succeed
    And the pod named "mypod2" becomes ready

    When admin executes on the pod:
      | chroot | /host | sysctl | crypto.fips_enabled |
    Then the step should succeed
    And the output should match:
      | crypto.fips_enabled = 1 |
    When admin executes on the pod:
      | chroot | /host | cat | /proc/sys/crypto/fips_enabled |
    Then the step should succeed
    And the output should match:
      | 1 |
