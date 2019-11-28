Feature: basic verification for upgrade testing

  # note that upuser1 and 2 need to be defined for the environement
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: prepare 2 users
    Given the user has all owned resources cleaned
    When I run the :new_project client command with:
      | project_name | upgrade-project-1 |
    Then the step should succeed
    And the output should contain:
      | project-ocp10017 |

  #@author geliu@redhat.com
  #@users=upuser1,upuser2
  #@case_id OCP-10017
  @admin
  Scenario: cakephp example works well after migrate
    Given I switch to cluster admin pseudo user
    Given I use the "project-ocp10017" project
    # This is upgrade example by geliu

  @upgrade-prepare
  @users=upuser1,upuser2
  # @author geliu@redhat.com
  # @case_id OCP-22606000
  @admin
  Scenario: upgrade-prepre etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/admin/subscription.yaml |
    Then the step should succeed
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/admin/etcd-cluster.yaml"
    When I run the :create client command with:
      | f | etcd-cluster.yaml |
    Then the step should succeed
    Then status becomes :running of exactly 3 pods labeled:
      | etcd_cluster=example |

  # @users=upuser1,upuser2
  # @author geliu@redhat.com
  # @case_id OCP-22606
  @admin
  Scenario: etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    Then status becomes :running of exactly 3 pods labeled:
      | etcd_cluster=example |

  # @case_id OCP-26309
  @upgrade-check
  Scenario: simple selector upgrade test case
    Given I log the message> Hi Check!

  @upgrade-prepare
  Scenario: simple selector upgrade test case - prepare
    Given I log the message> Hi Prepare!
