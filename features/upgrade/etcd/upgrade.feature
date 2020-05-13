Feature: basic verification for upgrade testing
  # @author geliu@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: etcd-operator and cluster works well after upgrade - prepare 
    Given I switch to cluster admin pseudo user		
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/admin/subscription.yaml |
    Then the step should succeed
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/admin/etcd-cluster.yaml |
    Then the step should succeed
    Then status becomes :running of exactly 3 pods labeled:
      | etcd_cluster=example |

  # @author geliu@redhat.com
  # @case_id OCP-22606
  @upgrade-check
  @admin
  Scenario: etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |

