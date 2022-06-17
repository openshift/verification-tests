Feature: testing multicast scenarios

  # @author hongli@redhat.com
  # @case_id OCP-12926
  @admin
  Scenario: OCP-12926 pods should be able to subscribe send and receive multicast traffic
    Given the env is using multitenant or networkpolicy network

    # create some multicast testing pods
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multicast-rc.json |
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
    When I run the :annotate admin command with:
      | resource     | netnamespace    |
      | resourcename | <%= cb.proj1 %> |
      | overwrite    | true            |
      | keyval       | netnamespace.network.openshift.io/multicast-enabled=true |
    Then the step should succeed
    
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
      | pod              | <%= cb.pod3 %> |
      | oc_opts_end      |                |
      | exec_command     | sh             |
      | exec_command_arg | -c             |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> <%= cb.pod3ip %> > /tmp/p3.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    When I execute on the "<%= cb.pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+232.43.211.234 |

    Given 10 seconds have passed
    When I execute on the "<%= cb.pod3 %>" pod:
      | cat | /tmp/p3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
      | <%= cb.pod2ip %>.*joined \(S,G\) = \(\*, 232.43.211.234\), pinging |
      | <%= cb.pod1ip %>.*multicast, xmt/rcv/%loss = 5/5/0% |
      | <%= cb.pod2ip %>.*multicast, xmt/rcv/%loss = 5/5/0% |

  # @author hongli@redhat.com
  # @case_id OCP-12977
  @admin
  Scenario: OCP-12977 multicast is disabled by default if not annotate the netnamespace
    Given the env is using multitenant or networkpolicy network

    # create multicast testing pods in the project and without multicast enable
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 2 |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard

    # run omping as background on the pods
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
    Then the step should succeed

    When I run the :exec background client command with:
      | pod              | <%= cb.pod2 %> |
      | oc_opts_end      |                |
      | exec_command     | sh             |
      | exec_command_arg | -c             |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> > /tmp/p2-disable.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    When I execute on the "<%= cb.pod2 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+232.43.211.234 |

    # check the result and should received 0 multicast packet
    Given 10 seconds have passed
    When I execute on the "<%= cb.pod2 %>" pod:
      | cat | /tmp/p2-disable.log |
    Then the step should succeed
    And the output should contain:
      | <%= cb.pod1ip %> : joined (S,G) = (*, 232.43.211.234), pinging |
      | <%= cb.pod1ip %> : multicast, xmt/rcv/%loss = 5/0/100%         |

