Feature: testing multicast scenarios

  # @author hongli@redhat.com
  # @case_id OCP-12926
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @proxy @noproxy @connected
  @network-multitenant
  @network-ovnkubernetes @network-openshiftsdn @network-networkpolicy
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-12926:SDN pods should be able to subscribe send and receive multicast traffic
    # create some multicast testing pods
    Given I store the schedulable workers in the :nodes clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 2                       |
      | ["spec"]["nodeName"] | <%= cb.nodes[0].name %> |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["metadata"]["name"]                               | "mcast-rc2"             |
      | ["spec"]["replicas"]                               | 1                       |
      | ["spec"]["nodeName"]                               | <%= cb.nodes[1].name %> |
      | ["spec"]["template"]["metadata"]["labels"]["name"] | "mcast2-pods"           |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=mcast2-pods |
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
      | eth0\s+1\s+(232.43.211.234\|ff3e::4321:1234) |
    """   
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | cat | /tmp/p3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
      | <%= cb.pod2ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
      | <%= cb.pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
    """
    
  # @author hongli@redhat.com
  # @case_id OCP-12977
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @network-multitenant
  @network-ovnkubernetes @network-openshiftsdn @network-networkpolicy
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-12977:SDN multicast is disabled by default if not annotate the namespace
    # create multicast testing pods in the project and without multicast enable
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 2 |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard

    # Enable multicast in proj1
    Given I enable multicast for the "<%= cb.proj1 %>" namespace
    
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
      | pod              | <%= cb.pod2 %>                                                            |
      | oc_opts_end      |                                                                           |
      | exec_command     | sh                                                                        |
      | exec_command_arg | -c                                                                        |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> > /tmp/p2-disable.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+(232.43.211.234\|ff3e::4321:1234) |
    """
    # check the result and should received 0 multicast packet
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2 %>" pod:
      | cat | /tmp/p2-disable.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %> : multicast, xmt/rcv/%loss = 5/0/100% |
    """

  # @author weliang@redhat.com
  # @case_id OCP-12930
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-multitenant
  @network-ovnkubernetes @network-openshiftsdn @network-networkpolicy
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-12930:SDN Same multicast groups can be created in multiple namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run the :create client command with:
      | f | multicast-rc.json |
    Then the step should succeed
    Given 3 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :proj1pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :proj1pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :proj1pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :proj1pod2 clipboard
    And evaluation of `pod(2).ip` is stored in the :proj1pod3ip clipboard
    And evaluation of `pod(2).name` is stored in the :proj1pod3 clipboard
    # Enable multicast in proj1
    Given I enable multicast for the "<%= cb.proj1 %>" namespace

    # Create second project
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run the :create client command with:
      | f | multicast-rc.json |
    Then the step should succeed
    Given 3 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(3).ip` is stored in the :proj2pod1ip clipboard
    And evaluation of `pod(3).name` is stored in the :proj2pod1 clipboard
    And evaluation of `pod(4).ip` is stored in the :proj2pod2ip clipboard
    And evaluation of `pod(4).name` is stored in the :proj2pod2 clipboard
    And evaluation of `pod(5).ip` is stored in the :proj2pod3ip clipboard
    And evaluation of `pod(5).name` is stored in the :proj2pod3 clipboard
    And evaluation of `pod(3).ip.include?(":") ? "ff3e::2552:5424" : "239.255.254.24"` is stored in the :multicast_ip clipboard
    # Enable multicast in proj2
    Given I enable multicast for the "<%= cb.proj2 %>" namespace

    # Check multicast group 239.255.254.24 stream in proj1
    Given I use the "<%= cb.proj1 %>" project
    # Enable multicast group 239.255.254.24 stream proj1pod1
    When I run the :exec background client command with:
      | pod              | <%= cb.proj1pod1 %>                                                                                   |
      | oc_opts_end      |                                                                                                       |
      | exec_command     | sh                                                                                                    |
      | exec_command_arg | -c                                                                                                    |
      | exec_command     | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj1pod1ip %> <%= cb.proj1pod2ip %> <%= cb.proj1pod3ip %> |
    Then the step should succeed
    # Enable multicast group 239.255.254.24 stream proj1pod2
    When I run the :exec background client command with:
      | pod              | <%= cb.proj1pod2 %>                                                                                   |
      | oc_opts_end      |                                                                                                       |
      | exec_command     | sh                                                                                                    |
      | exec_command_arg | -c                                                                                                    |
      | exec_command     | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj1pod1ip %> <%= cb.proj1pod2ip %> <%= cb.proj1pod3ip %> |
    Then the step should succeed
    # Enable multicast group 239.255.254.24 stream proj1pod3
    When I run the :exec background client command with:
      | pod              | <%= cb.proj1pod3 %>                                                                                                        |
      | oc_opts_end      |                                                                                                                            |
      | exec_command     | sh                                                                                                                         |         
      | exec_command_arg | -c                                                                                                                         |
      | exec_command_arg | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj1pod1ip %> <%= cb.proj1pod2ip %> <%= cb.proj1pod3ip %> > /tmp/proj1pod3.log |
    Then the step should succeed

    # Ensure proj1pod3 interface join to the multicast group 239.255.254.24
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj1pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+<%= cb.multicast_ip %> |
    """
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj1pod3 %>" pod:
      | cat | /tmp/proj1pod3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.proj1pod1ip %>.*joined \(S,G\) = \(\*, <%= cb.multicast_ip %>\), pinging |
      | <%= cb.proj1pod2ip %>.*joined \(S,G\) = \(\*, <%= cb.multicast_ip %>\), pinging |
    And the output should not match:
      | <%= cb.proj1pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0%                |
      | <%= cb.proj1pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0%                |
    """

    # Check multicast group 239.255.254.24 stream in proj2
    Given I use the "<%= cb.proj2 %>" project
    # Enable multicast group 239.255.254.24 stream proj2pod1
    When I run the :exec background client command with:
      | pod              | <%= cb.proj2pod1 %>                                                                                   |
      | oc_opts_end      |                                                                                                       |
      | exec_command     | sh                                                                                                    |
      | exec_command_arg | -c                                                                                                    |
      | exec_command     | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj2pod1ip %> <%= cb.proj2pod2ip %> <%= cb.proj2pod3ip %> |
    Then the step should succeed
    # Enable multicast group 239.255.254.24 stream proj2pod2
    When I run the :exec background client command with:
      | pod              | <%= cb.proj2pod2 %>                                                                                   |
      | oc_opts_end      |                                                                                                       |
      | exec_command     | sh                                                                                                    |
      | exec_command_arg | -c                                                                                                    |
      | exec_command     | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj2pod1ip %> <%= cb.proj2pod2ip %> <%= cb.proj2pod3ip %> |
    Then the step should succeed
    # Enable multicast group 239.255.254.24 stream proj2pod3
    When I run the :exec background client command with:
      | pod              | <%= cb.proj2pod3 %>                                                                                                        |
      | oc_opts_end      |                                                                                                                            |
      | exec_command     | sh                                                                                                                         |
      | exec_command_arg | -c                                                                                                                         |
      | exec_command_arg | omping -m <%= cb.multicast_ip %> -c 5 -T 10 <%= cb.proj2pod1ip %> <%= cb.proj2pod2ip %> <%= cb.proj2pod3ip %> > /tmp/proj2pod3.log |
    Then the step should succeed

    # Ensure proj2pod3 interface join to the multicast group 239.255.254.24
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj2pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+<%= cb.multicast_ip %> |
    """
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj2pod3 %>" pod:
      | cat | /tmp/proj2pod3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.proj2pod1ip %>.*joined \(S,G\) = \(\*, <%= cb.multicast_ip %>\), pinging |
      | <%= cb.proj2pod2ip %>.*joined \(S,G\) = \(\*, <%= cb.multicast_ip %>\), pinging |
    And the output should not match:
      | <%= cb.proj2pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0%                |
      | <%= cb.proj2pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0%                |
    """

  # @author hongli@redhat.com
  # @case_id OCP-12931
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-12931:SDN pods in default project should not be able to receive multicast traffic from other namespace
    # create multicast testing pod in one project
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=mcast-pods |
    And evaluation of `pod.ip` is stored in the :proj1_podip clipboard
    And evaluation of `pod.name` is stored in the :proj1_pod clipboard

    # enable multicast for the netnamespace
    Given I enable multicast for the "<%= cb.proj1 %>" namespace

    # enable multicast and create testing pods in default project
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    Given I enable multicast for the "default" namespace

    Given admin ensures "mcast-rc" rc is deleted after scenario
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=mcast-pods |
    And evaluation of `pod.ip` is stored in the :proj2_podip clipboard
    And evaluation of `pod.name` is stored in the :proj2_pod clipboard

    # run omping on the pod in first project
    Given I use the "<%= cb.proj1 %>" project
    When I run the :exec background client command with:
      | pod              | <%= cb.proj1_pod %>                                                         |
      | oc_opts_end      |                                                                             |
      | exec_command     | sh                                                                          |
      | exec_command_arg | -c                                                                          |
      | exec_command_arg | omping -c 5 -T 15 <%= cb.proj1_podip %> <%= cb.proj2_podip %> > /tmp/p1.log |
    Then the step should succeed

    # run omping on the pod in default project
    Given I use the "default" project
    When I run the :exec background client command with:
      | pod              | <%= cb.proj2_pod %>                                                         |
      | oc_opts_end      |                                                                             |
      | exec_command     | sh                                                                          |
      | exec_command_arg | -c                                                                          |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.proj1_podip %> <%= cb.proj2_podip %> > /tmp/p2.log |
    Then the step should succeed

    # check the result and should receive 0 multicast packet
    Given I use the "<%= cb.proj1 %>" project
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj1_pod %>" pod:
      | cat | /tmp/p1.log |
    Then the step should succeed
    And the output should match:
      | joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
      | multicast, xmt/rcv/%loss = 5/0/100%                                 |
    """
    And I wait up to 20 seconds for the steps to pass:
    """
    Given I use the "default" project
    When I execute on the "<%= cb.proj2_pod %>" pod:
      | cat | /tmp/p2.log |
    Then the step should succeed
    And the output should match:
      | joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
      | multicast, xmt/rcv/%loss = 5/0/100%                                 |
    """  
    Given I disable multicast for the "default" namespace
    
  # @author hongli@redhat.com
  # @case_id OCP-12928
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-12928:SDN pods should be able to join multiple multicast groups at same time  
    # create some multicast testing pods in the project
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 2 |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=mcast-pods |
    And evaluation of `pod(0).ip` is stored in the :pod1ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard
    And evaluation of `pod(1).ip.include?(":") ? "ff3e::4321:1235" : "232.43.211.235"` is stored in the :multicast_ip clipboard

    # enable multicast for the netnamespace
    Given I enable multicast for the "<%= cb.proj1 %>" namespace

    # run omping with default group (232.43.211.234) on first pod
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

    # run omping with another group 232.43.211.235 on first pod
    When I run the :exec background client command with:
      | pod              | <%= cb.pod1 %>         |
      | oc_opts_end      |                        |
      | exec_command     | omping                 |
      | exec_command_arg | -c                     |
      | exec_command_arg | 5                      |
      | exec_command_arg | -T                     |
      | exec_command_arg | 15                     |
      | exec_command_arg | -m                     |
      | exec_command_arg | <%= cb.multicast_ip %> |
      | exec_command_arg | -p                     |
      | exec_command_arg | 4322                   |
      | exec_command_arg | <%= cb.pod1ip %>       |
      | exec_command_arg | <%= cb.pod2ip %>       |
    Then the step should succeed

    # run omping on second pod
    When I run the :exec background client command with:
      | pod              | <%= cb.pod2 %>                                                      |
      | oc_opts_end      |                                                                     |
      | exec_command     | sh                                                                  |
      | exec_command_arg | -c                                                                  |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> > /tmp/p2g1.log |
    Then the step should succeed
    When I run the :exec background client command with:
      | pod              | <%= cb.pod2 %>                                                                                |
      | oc_opts_end      |                                                                                               |
      | exec_command     | sh                                                                                            |
      | exec_command_arg | -c                                                                                            |
      | exec_command_arg | omping -c 5 -T 10 -m <%= cb.multicast_ip %> -p 4322 <%= cb.pod1ip %> <%= cb.pod2ip %> > /tmp/p2g2.log |
    Then the step should succeed

    # ensure pod joined both multicast groups
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+(232.43.211.234\|ff3e::4321:1234) |
      | eth0\s+1\s+<%= cb.multicast_ip %> |
    """   
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2 %>" pod:
      | cat | /tmp/p2g1.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %> : multicast, xmt/rcv/%loss = 5/0/0% |
    When I execute on the "<%= cb.pod2 %>" pod:
      | cat | /tmp/p2g2.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, <%= cb.multicast_ip %>\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %> : multicast, xmt/rcv/%loss = 5/0/0% |
    """

  # @author hongli@redhat.com
  # @case_id OCP-12929
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-12929:SDN pods should not be able to receive multicast traffic from other pods in different namespace
    # create some multicast testing pods in one project
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 1                       |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=mcast-pods |
    And evaluation of `pod.ip` is stored in the :proj1_podip clipboard
    And evaluation of `pod.name` is stored in the :proj1_pod clipboard

    # enable multicast for the netnamespace
    Given I enable multicast for the "<%= cb.proj1 %>" namespace

    # create some multicast testing pods in another project
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I obtain test data file "networking/multicast-rc.json"
    When I run oc create over "multicast-rc.json" replacing paths:
      | ["spec"]["replicas"] | 1                       |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=mcast-pods |
    And evaluation of `pod.ip` is stored in the :proj2_podip clipboard
    And evaluation of `pod.name` is stored in the :proj2_pod clipboard

    # enable multicast for the netnamespace
    Given I enable multicast for the "<%= cb.proj2 %>" namespace

    # run omping on pod in first project
    Given I use the "<%= cb.proj1 %>" project
    When I run the :exec background client command with:
      | pod              | <%= cb.proj1_pod %>   |
      | oc_opts_end      |                       |
      | exec_command     | omping                |
      | exec_command_arg | -c                    |
      | exec_command_arg | 5                     |
      | exec_command_arg | -T                    |
      | exec_command_arg | 15                    |
      | exec_command_arg | <%= cb.proj1_podip %> |
      | exec_command_arg | <%= cb.proj2_podip %> |
    Then the step should succeed

    # check the omping result on pod in second project
    Given I use the "<%= cb.proj2 %>" project
    When I run the :exec background client command with:
      | pod              | <%= cb.proj2_pod %>                                                         |
      | oc_opts_end      |                                                                             |
      | exec_command     | sh                                                                          |
      | exec_command_arg | -c                                                                          |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.proj1_podip %> <%= cb.proj2_podip %> > /tmp/p2.log |
    Then the step should succeed

    And I wait up to 10 seconds for the steps to pass:
    """  
    When I execute on the "<%= cb.proj2_pod %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+(232.43.211.234\|ff3e::4321:1234) |
    """   
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.proj2_pod %>" pod:
      | cat | /tmp/p2.log |
    Then the step should succeed
    And the output should contain:
      | multicast, xmt/rcv/%loss = 5/0/100% |
    """
 
  # @author hongli@redhat.com
  # @case_id OCP-12966
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-12966:SDN pods in default project should be able to receive multicast traffic from other default project pods
    # enable multicast and create testing pods
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    Given I enable multicast for the "default" namespace

    Given admin ensures "mcast-rc" rc is deleted after scenario
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

    # run omping as background on the pods
    When I run the :exec background client command with:
      | pod              | <%= cb.pod1 %>   |
      | oc_opts_end      |                  |
      | exec_command     | omping           |
      | exec_command_arg | -c               |
      | exec_command_arg | 5                |
      | exec_command_arg | -T               |
      | exec_command_arg | 10               |
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
      | exec_command_arg | 10               |
      | exec_command_arg | <%= cb.pod1ip %> |
      | exec_command_arg | <%= cb.pod2ip %> |
      | exec_command_arg | <%= cb.pod3ip %> |
    Then the step should succeed

    When I run the :exec background client command with:
      | pod              | <%= cb.pod3 %>                                                                     |
      | oc_opts_end      |                                                                                    |
      | exec_command     | sh                                                                                 |
      | exec_command_arg | -c                                                                                 |
      | exec_command_arg | omping -c 5 -T 10 <%= cb.pod1ip %> <%= cb.pod2ip %> <%= cb.pod3ip %> > /tmp/p3.log |
    Then the step should succeed

    # ensure interface join to the multicast group
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | netstat | -ng |
    Then the step should succeed
    And the output should match:
      | eth0\s+1\s+(232.43.211.234\|ff3e::4321:1234) |
    """

    # check the result on third pod and should received 5 multicast packets from other pods
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod3 %>" pod:
      | cat | /tmp/p3.log |
    Then the step should succeed
    And the output should match:
      | <%= cb.pod1ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
      | <%= cb.pod2ip %>.*joined \(S,G\) = \(\*, (232.43.211.234\|ff3e::4321:1234)\), pinging |
    And the output should not match:
      | <%= cb.pod1ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
      | <%= cb.pod2ip %>.*multicast, xmt/rcv/%loss = 5/0/0% |
    """
    Given I disable multicast for the "default" namespace
