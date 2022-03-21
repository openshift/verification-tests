Feature: SDN sctp compoment upgrade testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @4.11 @4.10 @4.9
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  Scenario: Check the sctp works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | sctp-upgrade |
    Then the step should succeed
    Given I store the ready and schedulable workers in the :workers clipboard
    And I install machineconfigs load-sctp-module
    And I wait up to 1600 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      |resource|nodes|
    Then the step should succeed
    Then the outputs should contain "Ready"
    Given I check load-sctp-module in all workers
    """

    When I use the "sctp-upgrade" project
    Given I obtain test data file "networking/sctp/sctpserver-upgrade.yaml"
    When I run the :create client command with:
      | f | sctpserver-upgrade.yaml |
      | n | sctp-upgrade            |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=sctpserver    |
    And evaluation of `pod.ip` is stored in the :serverpod_ip clipboard
    And evaluation of `pod.name` is stored in the :sctpserver clipboard

    Given I obtain test data file "networking/sctp/sctpclient-upgrade.yaml"
    When I run the :create client command with:
      | f | sctpclient-upgrade.yaml |
      | n | sctp-upgrade            |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=sctpclient    |
    And evaluation of `pod(1).name` is stored in the :sctpclient clipboard

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :exec background client command with:
      | pod              | <%= cb.sctpserver %>        |
      | namespace        | sctp-upgrade                |
      | oc_opts_end      |                             |
      | exec_command     | bash                        |
      | exec_command_arg | -c                          |
      | exec_command_arg | ncat -l 30102 --sctp        |
    Then the step should succeed
    # sctpclient pod start to send sctp traffic
    When I run the :exec client command with:
      | pod              | <%= cb.sctpclient %>                                               |
      | namespace        | sctp-upgrade                                                       |
      | oc_opts_end      |                                                                    |
      | exec_command     | bash                                                               |
      | exec_command_arg | -c                                                                 |
      | exec_command_arg | echo test-openshift \| ncat -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should succeed
    """


  # @author weliang@redhat.com
  # @case_id OCP-44765
  @admin
  @upgrade-check
  @4.11 @4.10 @4.9
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @upgrade
  Scenario: Check the sctp works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "sctp-upgrade" project
    Given a pod becomes ready with labels:
      | name=sctpserver    |
    And evaluation of `pod.ip` is stored in the :serverpod_ip clipboard
    And evaluation of `pod.name` is stored in the :sctpserver clipboard
    Given a pod becomes ready with labels:
      | name=sctpclient    |
    And evaluation of `pod(1).name` is stored in the :sctpclient clipboard
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :exec background client command with:
      | pod              | <%= cb.sctpserver %>        |
      | namespace        | sctp-upgrade                |
      | oc_opts_end      |                             |
      | exec_command     | bash                        |
      | exec_command_arg | -c                          |
      | exec_command_arg | ncat -l 30102 --sctp |
    Then the step should succeed
    # sctpclient pod start to send sctp traffic
    When I run the :exec client command with:
      | pod              | <%= cb.sctpclient %>                                             |
      | namespace        | sctp-upgrade                                                     |
      | oc_opts_end      |                                                                  |
      | exec_command     | bash                                                             |
      | exec_command_arg | -c                                                               |
      | exec_command_arg | echo test-openshift \| ncat -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should succeed
    """

    # delete the created project
    Given the "sctp-upgrade" project is deleted
