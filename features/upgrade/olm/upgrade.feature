@olm
Feature: OLM related scenarios
    
  # @author jiazha@redhat.com
  # @case_id OCP-22615
  @admin
  @upgrade-prepare
  @users=upuser1
  Scenario: upgrade OLM - prepare
    # Check OLM version
    Given The "operator-lifecycle-manager" operator version matchs the current cluster version
    # Check cluster operator OLM status
    Given The status of condition "Degraded" for "operator-lifecycle-manager" operator is: False
    Given The status of condition "Progressing" for "operator-lifecycle-manager" operator is: False
    Given The status of condition "Available" for "operator-lifecycle-manager" operator is: True
    Given The status of condition "Upgradeable" for "operator-lifecycle-manager" operator is: True
    # Create a namespace and an operator in it
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | olm-upgrade |
    Given etcd operator "etcd-test" is installed successfully in "olm-upgrade" project
    # Create customer resource in it
    Given etcdCluster "sample-cluster" is installed successfully in "olm-upgrade" project
    
  @admin
  @users=upuser1
  @upgrade-check
  Scenario: upgrade OLM
    # Check OLM version after upgraded
    Given The "operator-lifecycle-manager" operator version matchs the current cluster version
    # Check cluster operator OLM status
    Given The status of condition "Degraded" for "operator-lifecycle-manager" operator is: False
    Given The status of condition "Progressing" for "operator-lifecycle-manager" operator is: False
    Given The status of condition "Available" for "operator-lifecycle-manager" operator is: True
    Given The status of condition "Upgradeable" for "operator-lifecycle-manager" operator is: True
    # Check if this operator works well by changing its customer resource
    Given I use the "olm-upgrade" project 
    When I run the :patch client command with:
      | resource      | etcdcluster            |
      | resource_name | sample-cluster         |
      | p             | {"spec": {"size": 4 }} |
      | type          | merge                  |
    Then the step should succeed
    Then I wait up to 180 seconds for the steps to pass:
    """
    And I run the :get client command with:
      | resource | pods                        |
      | l        | etcd_cluster=sample-cluster |
    Then the output should match 4 times:
      | sample-cluster.* | 
    """
    # Clean this operator and its resource
    Given etcdCluster "sample-cluster" is removed successfully from "<%= cb.user_project %>" project
    Given etcd operator "etcd-test" is removed successfully from "<%= cb.user_project %>" project
    # This operator can be re-installed succefully
    Given etcd operator "etcd-test" is installed successfully in "olm-upgrade" project
