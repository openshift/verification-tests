Feature: projects related features via cli

  # @author cryan@redhat.com
  # @case_id OCP-12561
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @osd_ccs @aro @rosa
  @hypershift-hosted
  @critical
  Scenario: OCP-12561:Authentication Could remove user and group from the current project
    Given I have a project
    When I run the :oadm_policy_add_role_to_user client command with:
      | role_name        | admin                              |
      | user_name        | <%= user(1, switch: false).name %> |
      | rolebinding_name | admin                              |
    Then the step should succeed
    When I run the :oadm_policy_add_role_to_group client command with:
      | role_name        | admin                                                     |
      | group_name       | system:serviceaccounts:<%= user(1, switch: false).name %> |
      | rolebinding_name | admin                                                     |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | rolebinding |
      | resource_name | admin       |
      | o             | wide        |
    Then the step should succeed
    And the output should match:
      | admin.*(<%= user.name %>, <%= user(1, switch: false).name %>.*system:serviceaccounts:<%= user(1, switch: false).name %>)? |
    When I run the :policy_remove_group client command with:
      | group_name | system:serviceaccounts:<%= user(1, switch: false).name %> |
    Then the step should succeed
    And the output should contain "Removing admin from groups"
    When I run the :get client command with:
      | resource      | rolebinding |
      | resource_name | admin       |
      | o             | wide        |
    Then the step should succeed
    And the output should match:
      | admin.*(<%= user.name %>, <%= user(1, switch: false).name %>)? |
    And the output should not contain "system:serviceaccounts:<%= user(1, switch: false).name %>"

  # @author yinzhou@redhat.com
  # @case_id OCP-11201
  @proxy
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @osd_ccs @aro @rosa
  @hypershift-hosted
  @critical
  Scenario: OCP-11201:Authentication Process with default FSGroup id can be ran when using the default MustRunAs as the RunAsGroupStrategy
    Given I have a project
    Given I obtain test data file "pods/hello-pod.json"
    When I run the :create client command with:
      | f | hello-pod.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-openshift |
    Then the expression should be true> project.uid_range(user:user).begin == pod.fs_group(user:user)

