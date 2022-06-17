Feature: SDN related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-10025
  @admin
  @destructive
  Scenario: OCP-10025 kubelet proxy could change to userspace mode
    Given the env is using one of the listed network plugins:
      | subnet      |
      | multitenant |
    Given I select a random node's host
    And the node network is verified
    And the node service is verified
    Given I switch to cluster admin pseudo user
    And I register clean-up steps:
    """
    Given 15 seconds have passed
    When I get the networking components logs of the node since "90s" ago
    And the output should contain "Using iptables Proxier"
    """

    Given I restart the network components on the node after scenario
    Given node config is merged with the following hash:
    """
    proxyArguments:
      proxy-mode:
         - userspace
    """
    Given I restart the network components on the node
    And I wait up to 120 seconds for the steps to pass:
    """
    Given I get the networking components logs of the node since "60s" ago
    And the output should contain "Using userspace Proxier"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11286
  @admin
  @destructive
  Scenario: OCP-11286 iptables rules will be repaired automatically once it gets destroyed
    Given I select a random node's host
    And the node iptables config is verified
    And the node service is restarted on the host after scenario

    Given the node standard iptables rules are removed
    Given 35 seconds have passed
    Given the node iptables config is verified

  # @author hongli@redhat.com
  # @case_id OCP-13847
  @admin
  Scenario: OCP-13847 an empty OPENSHIFT-ADMIN-OUTPUT-RULES chain is created in filter table at startup
    Given the master version >= "3.6"
    Given I select a random node's host
    And the node service is verified

    When I run commands on the host:
      | iptables -S -t filter \| grep 'OPENSHIFT-ADMIN-OUTPUT-RULES' |
    Then the step should succeed
    And the output should contain:
      | -N OPENSHIFT-ADMIN-OUTPUT-RULES |
      | -A FORWARD -i tun0 ! -o tun0 -m comment --comment "administrator overrides" -j OPENSHIFT-ADMIN-OUTPUT-RULES |

  # @author bmeng@redhat.com
  # @case_id OCP-16217
  @admin
  @destructive
  Scenario: OCP-16217 SDN will detect the version and plugin type mismatch in openflow and restart node automatically
    Given the master version >= "3.10"
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :node_name clipboard

    #Below step will save plugin type and version value in net_plugin variable
    Given the cluster network plugin type and version and stored in the clipboard 
    #Changing plugin version to some arbitary value ff
    When I run command on the "<%= cb.node_name %>" node's sdn pod: 
      | ovs-ofctl| -O | openflow13 | mod-flows | br0 | table=253, actions=note:<%= cb.net_plugin[:type] %>.ff |
    Then the step should succeed
    And evaluation of `pod` is stored in the clipboard
    #Expecting sdn pod to be restarted due to vesion value change
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | namespace     | openshift-sdn     |
      | since         | 30s               |
    Then the step should succeed
    And the output should contain:
      | full SDN setup required (plugin is not setup) |
      | Starting openshift-sdn network plugin         |
    
    """
    # Expecting sdn pod to come back to default version the cluser was on initially
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I run command on the "<%= cb.node_name %>" node's sdn pod: 
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 |
    Then the step should succeed
    Then the output should contain "<%= cb.net_plugin[:type] %>.<%= cb.net_plugin[:version] %>"
    """
    #Changing plugin type to some arbitary value 99
    When I run command on the "<%= cb.node_name %>" node's sdn pod: 
      | ovs-ofctl| -O | openflow13 | mod-flows | br0 | table=253, actions=note:99.<%= cb.net_plugin[:version] %> |
    Then the step should succeed
    #Expecting sdn pod to be restarted due to plugin type value change
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | namespace     | openshift-sdn     |
      | since         | 30s               |
    Then the step should succeed
    And the output should contain:
      | full SDN setup required (plugin is not setup) |
      | Starting openshift-sdn network plugin         |
    
    """
    # Expecting sdn pod to come back to default type the cluster was on initially
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I run command on the "<%= cb.node_name %>" node's sdn pod: 
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 |
    Then the step should succeed
    Then the output should contain "<%= cb.net_plugin[:type] %>.<%= cb.net_plugin[:version] %>"
    """

  # @author yadu@redhat.com
  # @case_id OCP-15251
  @admin
  @destructive
  Scenario: OCP-15251 net.ipv4.ip_forward should be always enabled on node service startup
    Given I select a random node's host
    And the node service is verified
    And the node network is verified
    And system verification steps are used:
    """
    When I run commands on the host:
      | sysctl net.ipv4.ip_forward |
    Then the step should succeed
    And the output should contain "net.ipv4.ip_forward = 1"
    """
    Given I restart the network components on the node after scenario
    And I register clean-up steps:
    """
    When I run commands on the host:
      | sysctl -w net.ipv4.ip_forward=1 |
    Then the step should succeed
    """

    When I run commands on the host:
      | sysctl -w net.ipv4.ip_forward=0 |
    Then the step should succeed
    Given I restart the network components on the node
    And I wait up to 120 seconds for the steps to pass:
    """
    Given I get the networking components logs of the node since "120s" ago
    And the output should contain "net/ipv4/ip_forward=0, it must be set to 1"
    """

  # @author hongli@redhat.com
  # @case_id OCP-14985
  @admin
  @destructive
  Scenario: OCP-14985 The openflow list will be cleaned after deleted the node
    Given environment has at least 2 nodes
    And I store the nodes in the :nodes clipboard
    Given I switch to cluster admin pseudo user

    # get node_1's host IP and save to clipboard
    Given I use the "<%= cb.nodes[1].name %>" node
    And the node network is verified
    And the node service is verified
    And I register clean-up steps:
    """
    Given I wait for the networking components of the node to become ready
    """
    And the node labels are restored after scenario
    And the node service is restarted on the host after scenario
    And evaluation of `host_subnet(cb.nodes[1].name).ip` is stored in the :hostip clipboard

    # check ovs rule in node_0
    Given I use the "<%= cb.nodes[0].name %>" node
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 2>/dev/null \| grep <%= cb.hostip %> |
    Then the step should succeed
    And the output should match:
      | table=10,.*tun_src=<%= cb.hostip %> actions=goto_table:30 |
      | table=50,.*arp,.*set_field:<%= cb.hostip %>->tun_dst |
      | table=90,.*ip,.*set_field:<%= cb.hostip %>->tun_dst |
      | table=111,.*set_field:<%= cb.hostip %>->tun_dst,.*goto_table:120 |

    # delete the node_1
    Given I use the "<%= cb.nodes[1].name %>" node
    When I run the :delete admin command with:
      | object_type       | node                    |
      | object_name_or_id | <%= cb.nodes[1].name %> |
    Then the step should succeed
    Given I wait for the networking components of the node to be terminated

    # again, check ovs rule in node_0
    Given I use the "<%= cb.nodes[0].name %>" node
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 2>/dev/null |
    Then the step should succeed
    And the output should not contain "<%= cb.hostip %>"

  # @author hongli@redhat.com
  # @case_id OCP-18535
  @admin
  Scenario: OCP-18535 should not show "No such device" message when run "ovs-vsctl show" command
    Given I have a project
    And I have a pod-for-ping in the project
    Then I use the "<%= pod.node_name(user: user) %>" node
    When I run the :delete client command with:
      | object_type       | pods      |
      | object_name_or_id | hello-pod |
    Then the step should succeed
    Given I wait for the resource "pod" named "hello-pod" to disappear
    When I run the ovs commands on the host:
      | ovs-vsctl show |
    Then the step should succeed
    And the output should not contain "No such device"

