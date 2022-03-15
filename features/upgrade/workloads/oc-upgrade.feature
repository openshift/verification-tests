Feature: basic verification for upgrade oc client testing
  # @author yinzhou@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
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
  @connected
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
  @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  Scenario: Check some container related oc commands still work for ocp45 after upgrade - prepare
    Given the master version >= "4.5"
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | workloads-upgrade |
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/hello-openshift@sha256:eb47fdebd0f2cc0c130228ca972f15eb2858b425a3df15f10f7bb519f60f0c96 |
    Then the step should succeed

  # @author yinzhou@redhat.com
  # @case_id OCP-33209
  @upgrade-check
  @admin
  @users=upuser1,upuser2
  @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @connected
  Scenario: Check some container related oc commands still work for ocp45 after upgrade
    Given I switch to the first user
    When I use the "workloads-upgrade" project
    Given status becomes :running of 1 pods labeled:
      | deployment=hello-openshift |
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
