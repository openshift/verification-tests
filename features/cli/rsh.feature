Feature: rsh.feature

  # @author cryan@redhat.com
  # @case_id OCP-10658
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-10658:Workloads Check oc rsh for simpler access to a remote shell
    Given I have a project
    Then evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "pods/pod_with_two_containers.json"
    When I run the :create client command with:
      | f | pod_with_two_containers.json |
    Then the step should succeed
    Given the pod named "doublecontainers" becomes ready
    When I run the :rsh client command with:
      | pod         | doublecontainers |
      | command     | echo             |
      | command_arg | my_test_string   |
    Then the step should succeed
    And the output should contain "my_test_string"
    When I run the :rsh client command with:
      | c           | hello-openshift-fedora |
      | pod         | doublecontainers       |
      | command     | echo                   |
      | command_arg | my_test_string         |
    Then the step should succeed
    And the output should contain "my_test_string"
    When I run the :rsh client command with:
      | c           | hello-openshift-fedora |
      | shell       | /bin/bash              |
      | pod         | doublecontainers       |
      | command     | echo                   |
      | command_arg | my_test_string         |
    Then the step should succeed
    And the output should contain "my_test_string"
    Given I create a new project
    When I run the :rsh client command with:
      | n           | <%= cb.proj_name %> |
      | pod         | doublecontainers    |
      | command     | echo                |
      | command_arg | my_test_string      |
    Then the step should succeed
    And the output should contain "my_test_string"

