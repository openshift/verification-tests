@olm
Feature: OLM related scenarios

  # @author jiazha@redhat.com
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @disconnected @connected
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @arm64 @amd64
  Scenario: upgrade OLM - prepare
    # Check OLM version
    Given the "operator-lifecycle-manager" operator version matches the current cluster version
    # Check cluster operator OLM status
    Given the status of condition "Degraded" for "operator-lifecycle-manager" operator is: False
    Given the status of condition "Progressing" for "operator-lifecycle-manager" operator is: False
    Given the status of condition "Available" for "operator-lifecycle-manager" operator is: True
    Given the status of condition "Upgradeable" for "operator-lifecycle-manager" operator is: True
    # # Create a namespace and an operator in it
    # Given I switch to cluster admin pseudo user
    # When I run the :new_project client command with:
    #   | project_name | olm-upgrade |
    # Given etcd operator "etcd-test" is installed successfully in "olm-upgrade" project
    # # Create customer resource in it
    # Given etcdCluster "sample-cluster" is installed successfully in "olm-upgrade" project

  # @author jiazha@redhat.com
  # @case_id OCP-22615
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @arm64 @amd64
  Scenario: upgrade OLM
    # Check OLM version after upgraded
    Given the "operator-lifecycle-manager" operator version matches the current cluster version
    # Check cluster operator OLM status
    Given the status of condition "Degraded" for "operator-lifecycle-manager" operator is: False
    Given the status of condition "Progressing" for "operator-lifecycle-manager" operator is: False
    Given the status of condition "Available" for "operator-lifecycle-manager" operator is: True
    Given the status of condition "Upgradeable" for "operator-lifecycle-manager" operator is: True
    # # Check if this operator works well by changing its customer resource
    # Given I switch to cluster admin pseudo user
    # And I use the "olm-upgrade" project
    # When I run the :patch client command with:
    #   | resource      | etcdcluster            |
    #   | resource_name | sample-cluster         |
    #   | p             | {"spec": {"size": 4 }} |
    #   | type          | merge                  |
    # Then the step should succeed
    # Given status becomes :succeeded of exactly 4 pods labeled:
    #   | etcd_cluster=sample-cluster |
    # Then the step should succeed
    # Given etcdCluster "sample-cluster" is removed successfully from "olm-upgrade" project
    # Given etcd operator "etcd-test" is removed successfully from "olm-upgrade" project
    # # This operator can be re-installed succefully
    # Given etcd operator "etcd-test" is installed successfully in "olm-upgrade" project
