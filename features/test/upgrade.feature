Feature: basic verification for upgrade testing

  # note that upuser1 and 2 need to be defined for the environement
  @upgrade-prepare
  @users=upuserX
  Scenario: OCP-10017 cakephp example works well after upgrade - prepare
    When I run the :new_project client command with:
      | project_name | project-ocp10017 |
    Then the step should succeed
    And I wait for the "project-ocp10017" project to appear

  # @author geliu@redhat.com
  # @case_id OCP-10017
  @admin
  @users=upuserX
  Scenario: OCP-10017 cakephp example works well after upgrade
    Given I switch to cluster admin pseudo user
    Given I use the "project-ocp10017" project

  # @author geliu@redhat.com
  @upgrade-prepare
  @users=upuserY
  @admin
  Scenario: OCP-22606 etcd-operator and cluster work well after upgrade - prepare
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

  # @author geliu@redhat.com
  # @case_id OCP-22606
  @admin
  @users=upuserY
  Scenario: OCP-22606 etcd-operator and cluster work well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    Then status becomes :running of exactly 3 pods labeled:
      | etcd_cluster=example |

  # @case_id OCP-26309
  @upgrade-check
  Scenario: OCP-26309 simple selector upgrade test case
    Given I log the message> Hi Check!

  @upgrade-prepare
  Scenario: OCP-26309 simple selector upgrade test case - prepare
    Given I log the message> Hi Prepare!
