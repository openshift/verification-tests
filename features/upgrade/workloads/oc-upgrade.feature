Feature: basic verification for upgrade oc client testing

  # @author yinzhou@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @singlenode
  @connected
  @admin
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  Scenario: Check some container related oc commands still work after upgrade - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | workloads-upgrade |
    When I run the :new_app client command with:
      | docker_image | aosqe/hello-openshift |
    Then the step should succeed

  # @author yinzhou@redhat.com
  # @case_id OCP-13032
  @upgrade-check
  @admin
  @users=upuser1,upuser2
  @singlenode
  @proxy @noproxy @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Check some container related oc commands still work after upgrade
    Given I switch to the first user
    When I use the "workloads-upgrade" project
    Given status becomes :running of 1 pods labeled:
      | deploymentconfig=hello-openshift |
    When I run the :rsh client command with:
      | pod     | <%= pod.name %> |
      | command | ls              |
      | command | /etc            |
    Then the step should succeed
    When I run the :exec client command with:
      | pod              | <%= pod.name %> |
      | exec_command     | cat             |
      | exec_command_arg | /etc/hosts      |
    Then the output should contain:
      | localhost |
    And evaluation of `rand(5000..7999)` is stored in the :port1 clipboard
    When I run the :port_forward background client command with:
      | pod       | <%= pod.name %>        |
      | port_spec | <%= cb[:port1] %>:8888 |
      | _timeout  | 100                    |
    Then the step should succeed
    Given I wait up to 30 seconds for the steps to pass:
    """
    Given the expression should be true> @host = localhost
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:port1] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    """

  # @author yinzhou@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @admin
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @hypershift-hosted
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario: Check some container related oc commands still work for ocp45 after upgrade - prepare
    Given the master version >= "4.5"
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | workloads-upgrade |
    When I run the :create_deployment client command with:
      | name          | octest                                                                                                        |
      | image         | quay.io/openshifttest/hello-openshift@sha256:b6296396b632d15daf9b5e62cf26da20d76157161035fefddbd0e7f7749f4167 |
    Then the step should succeed

  # @author yinzhou@redhat.com
  # @case_id OCP-33209
  @upgrade-check
  @admin
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: Check some container related oc commands still work for ocp45 after upgrade
    Given I switch to the first user
    When I use the "workloads-upgrade" project
    Given status becomes :running of 1 pods labeled:
      | app=octest |
    When I run the :rsh client command with:
      | pod     | <%= pod.name %> |
      | command | ls              |
      | command | /etc            |
    Then the step should succeed
    When I run the :exec client command with:
      | pod              | <%= pod.name %> |
      | exec_command     | cat             |
      | exec_command_arg | /etc/hosts      |
    Then the output should contain:
      | localhost |
    And evaluation of `rand(5000..7999)` is stored in the :port1 clipboard
    When I run the :port_forward background client command with:
      | pod       | <%= pod.name %>        |
      | port_spec | <%= cb[:port1] %>:8081 |
      | _timeout  | 100                    |
    Then the step should succeed
    Given I wait up to 30 seconds for the steps to pass:
    """
    Given the expression should be true> @host = localhost
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:port1] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    """
