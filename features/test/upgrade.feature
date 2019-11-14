Feature: basic verification for upgrade testing
  # @author geliu@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  # @case_id OCP-10017000
  Scenario: upgrade-prepre cakephp example works well after migrate

    When I run the :new_project client command with:
      | project_name | project-ocp10017 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | project |
    Then the step should succeed
    And the output should contain:
      | project-ocp10017 |

  @admin
  #@users=upuser1,upuser2
  #@case_id OCP-10017
  Scenario: cakephp example works well after migrate
    Given I switch to cluster admin pseudo user
    Given I use the "project-ocp10017" project
    # This is upgrade example by geliu

  @upgrade-prepare
  @users=upuser1,upuser2 
  # @author geliu@redhat.com
  # @case_id OCP-22606000
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
  
  #@users=upuser1,upuser2  
  @admin
  # @author geliu@redhat.com
  # @case_id OCP-22606
  Scenario: etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    Then status becomes :running of exactly 3 pods labeled:
      | etcd_cluster=example |

