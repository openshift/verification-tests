 Feature: SDN multicast compoment upgrade testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @4.11 @4.10 @4.9
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  Scenario: Check the multicast works well after upgrade - prepare
    # create some multicast testing pods
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | multicast-upgrade |
    Then the step should succeed
    When I use the "multicast-upgrade" project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run the :create client command with:
      | f | multicast-rc.json |
    Then the step should succeed
    Given 3 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard
    And evaluation of `pod(2).ip` is stored in the :pod3ip clipboard
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard

    # enable multicast for the netnamespace
    Given I enable multicast for the "<%= cb.proj1 %>" namespace

    # run omping as background on first and second pods
    When I run the :exec background client command with:
      | pod              | <%= cb.pod1 %>   |
      | oc_opts_end      |                  |
      | exec_command     | omping           |
      | exec_command_arg | -c               |
      | exec_command_arg | 5                |
      | exec_command_arg | -T               |
      | exec_command_arg | 15               |
      | exec_command_arg | <%= cb.pod1ip %> |
      | exec_command_arg | <%= cb.pod2ip %> |
      | exec_command_arg | <%= cb.pod3ip %> |
    Then the step should succeed

    When I run the :exec background client command with:
      | pod              | <%= cb.pod2 %>   |
      | oc_opts_end      |                  |
      | exec_command     | omping           |
      | exec_command_arg | -c               |
      | exec_command_arg | 5                |
      | exec_command_arg | -T               |
      | exec_command_arg | 15               |
      | exec_command_arg | <%= cb.pod1ip %> |
      | exec_command_arg | <%= cb.pod2ip %> |
      | exec_command_arg | <%= cb.pod3ip %> |
    Then the step should succeed

    # check the omping result on third pod
    When I run the :exec background client command with:
      | pod              | <%= cb.pod3 %>                                                                     |
      | oc_opts_end      |                                                                                    |
      | exec_command     | sh                                                                                 |
      | exec_command_arg | -c                                                                                 |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> <%= cb.pod3ip %> > /tmp/p3.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+232.43.211.234 |
    """
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | cat | /tmp/p3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
      | <%= cb.pod2ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
      | <%= cb.pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
    """

  # @author weliang@redhat.com
  # @case_id OCP-44636
  @admin
  @upgrade-check
  @4.11 @4.10 @4.9
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @upgrade
  @network-ovnkubernetes
  Scenario: Check the multicast works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "multicast-upgrade" project
    Given 3 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard
    And evaluation of `pod(2).ip` is stored in the :pod3ip clipboard
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard

    # run omping as background on first and second pods
    When I run the :exec background client command with:
      | pod              | <%= cb.pod1 %>   |
      | oc_opts_end      |                  |
      | exec_command     | omping           |
      | exec_command_arg | -c               |
      | exec_command_arg | 5                |
      | exec_command_arg | -T               |
      | exec_command_arg | 15               |
      | exec_command_arg | <%= cb.pod1ip %> |
      | exec_command_arg | <%= cb.pod2ip %> |
      | exec_command_arg | <%= cb.pod3ip %> |
    Then the step should succeed

    When I run the :exec background client command with:
      | pod              | <%= cb.pod2 %>   |
      | oc_opts_end      |                  |
      | exec_command     | omping           |
      | exec_command_arg | -c               |
      | exec_command_arg | 5                |
      | exec_command_arg | -T               |
      | exec_command_arg | 15               |
      | exec_command_arg | <%= cb.pod1ip %> |
      | exec_command_arg | <%= cb.pod2ip %> |
      | exec_command_arg | <%= cb.pod3ip %> |
    Then the step should succeed

    # check the omping result on third pod
    When I run the :exec background client command with:
      | pod              | <%= cb.pod3 %>                                                                     |
      | oc_opts_end      |                                                                                    |
      | exec_command     | sh                                                                                 |
      | exec_command_arg | -c                                                                                 |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> <%= cb.pod3ip %> > /tmp/p3.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+232.43.211.234 |
    """
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | cat | /tmp/p3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
      | <%= cb.pod2ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
      | <%= cb.pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
    """
