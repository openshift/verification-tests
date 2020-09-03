Feature: Egress IP related features

  # @author bmeng@redhat.com
  # @case_id OCP-15465
  @admin
  Scenario: Only cluster admin can add/remove egressIPs on hostsubnet
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard

    # Try to add the egress ip to the hostsubnet with normal user
    When I run the :patch client command with:
      | resource      | hostsubnet |
      | resource_name | <%= cb.egress_node %> |
      | p             | {"egressIPs":["<%= cb.valid_ip %>"]} |
    Then the step should fail
    And the output should contain "Forbidden"

  # @author bmeng@redhat.com
  # @case_id OCP-15466
  Scenario: Only cluster admin can add/remove egressIPs on netnamespaces
    # Try to add the egress ip to the netnamespace with normal user
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard
    When I run the :patch client command with:
      | resource      | netnamespace |
      | resource_name | <%= cb.project %> |
      | p             | {"egressIPs":["<%= cb.valid_ip %>"]} |
    Then the step should fail
    And the output should contain "Forbidden"

  # @author bmeng@redhat.com
  # @case_id OCP-15471
  @admin
  Scenario: All the pods egress connection will get out through the egress IP if the egress IP is set to netns and egress node can host the IP
    Given I select a random node's host
    # create project with pods
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard

    # add the egress ip to the hostsubnet
    And the valid egress IP is added to the node

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # create some more pods after the egress ip patched
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 4                      |
    Then the step should succeed
    Given 4 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard
    And evaluation of `pod(3).name` is stored in the :pod4 clipboard

    # try to access the receiver service to get the source IP

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-15472
  @admin
  Scenario: The egressIPs will be added to the node's primary NIC when it gets set on hostsubnet and will be removed after gets unset
    # add the egress ip to the hostsubnet
    Given  the valid egress IP is added to the node
    And evaluation of `node.name` is stored in the :egress_node clipboard

    # add the egress ip to the project
    Given I have a project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # check egress ip was added to primary interface
    When I run command on the "<%= cb.egress_node %>" node's sdn pod:
      | bash | -c | ip address show <%= cb.interface %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    # Remove the egress ip from hostsbunet
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.egress_node %>" with:
      | {"egressIPs": null} |

     # check egress ip was removed from primary interface
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run command on the "<%= cb.egress_node %>" node's sdn pod:
      | bash | -c | ip address show <%= cb.interface %> |
    Then the step should succeed
    And the output should not contain "<%= cb.valid_ip %>"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-21812
  # @bug_id  1609112
  @admin
  @destructive
  Scenario: Should remove the egressIP from the array if it was not being used
    Given I store a random unused IP address from the reserved range to the clipboard
    And evaluation of `IPAddr.new("<%= cb.valid_ip %>").to_i + 1 ` is stored in the :newipint clipboard
    And evaluation of `IPAddr.new(<%= cb.newipint %>, Socket::AF_INET).to_s` is stored in the :newip clipboard

    #Patch egress cidr to the node
    Given as admin I successfully merge patch resource "hostsubnet/<%= node.name %>" with:
      | {"egressCIDRs": ["<%= cb.subnet_range %>"] }   |
    And I register clean-up steps:
    """
    as admin I successfully merge patch resource "hostsubnet/<%= node.name %>" with:
      | {"egressCIDRs":null}   |
    """

    # Patch egress IP to the project twice
    Given I have a project
    And as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.newip %>"]} |
    And as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # Check the egress ip is the last one applied
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run command on the "<%= node.name%>" node's sdn pod:
      | bash | -c | ip address show <%= cb.interface %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    And the output should not contain "<%= cb.newip %>"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-15992
  @admin
  @destructive
  Scenario: The EgressNetworkPolicy should work well with egressIP
    Given the valid egress IP is added to the node
    And I have a project
    And I have a pod-for-ping in the project

    # Create egressnetworkpolicy
    Given I obtain test data file "networking/egressnetworkpolicy/limit_policy.json"
    When I run the :create admin command with:
      | f | limit_policy.json |
      | n | <%= project.name %>                                                                                                 |
    Then the step should succeed

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    #The traffic should be denied
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should fail

    # Update egressnetworkpolicy as Allow
    When I run the :patch admin command with:
      | resource      | egressnetworkpolicy                                                       |
      | resource_name | policy1                                                                   |
      | p             | {"spec":{"egress":[{"type":"Allow","to":{"cidrSelector": "0.0.0.0/0"}}]}} |
      | n             | <%= project.name %>                                                       |
      | type          | merge                                                                     |
    Then the step should succeed

    # The traffic should be allowed and the source ip is egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-15473
  @admin
  @destructive
  Scenario: The related iptables/openflow rules will be removed once the egressIP gets removed from netnamespace
    Given the valid egress IP is added to the node
    And I have a project

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    #Check related iptables added
    When I run command on the "<%= node.name%>" node's sdn pod:
      | bash | -c | iptables-save \| grep "<%= cb.valid_ip %>" |
    Then the step should succeed
    And the output should contain:
      | OPENSHIFT-MASQUERADE      |
      | OPENSHIFT-FIREWALL-ALLOW  |

    #check related openflow added
    When I run command on the "<%= node.name%>" node's sdn pod:
      | bash | -c | ovs-ofctl dump-flows br0 -O OpenFlow13 \| grep table=100 |
    Then the step should succeed
    And the output should contain "reg0=0x"

    #Remove egress ip from namespace
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": null} |

    # Check related iptables and openlows removed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run command on the "<%= node.name%>" node's sdn pod:
      | bash | -c | iptables-save \| egrep "OPENSHIFT-FIREWALL-ALLOW\|OPENSHIFT-MASQUERADE" |
    Then the step should succeed
    And the output should not contain:
      |  <%= cb.valid_ip %> |
    When I run command on the "<%= node.name%>" node's sdn pod:
      | bash | -c | ovs-ofctl dump-flows br0 -O OpenFlow13 \| grep table=100 |
    Then the step should succeed
    And the output should not contain "reg0=0x"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-19973
  @admin
  @destructive
  Scenario: The egressIP should still work fine after the node or network service restarted
    Given the valid egress IP is added to the node
    And I have a project
    And I have a pod-for-ping in the project

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    #Restart the network service
    Given I restart the network components on the node
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    """

    # Reboot the node which patched egressIP
    Given the host is rebooted and I wait it up to 600 seconds to become available
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-15998
  @admin
  Scenario Outline: Invalid egressIP should not be acceptable
    Given I select a random node's host
    When I run the :patch admin command with:
      | resource      | hostsubnet                     |
      | resource_name | <%= node.name %>               |
      | p             | {"egressIPs": <invalid_ip> }   |
      | type          | merge                          |
    Then the step should fail
    And the output should contain "Invalid JSON Patch"

    Examples:
      | invalid_ip              |
      | fe80::5054:ff:fedd:3698 |
      | a.b.c.d                 |
      | 10.10.10.-1             |
      | 10.0.0.1/64             |
      | 10.1.1/24               |
      | A008696                 |

  # @author huirwang@redhat.com
  # @case_id OCP-25694
  @admin
  @destructive
  Scenario: Random outages with egressIP
    Given I store the schedulable workers in the :nodes clipboard
    And the valid egress IP is added to the "<%= cb.nodes[0].name %>" node
    And I have a project
    Given I obtain test data file "networking/aosqe-pod-for-ping.json"
    When I run oc create over "aosqe-pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.nodes[1].name %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-pod |

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # Access some external host that is not responding
    When I execute on the pod:
      | nc | -v | -w2 | 8.8.8.8 | 23 |
    Then the step should fail
    And the output should contain "Operation timed out"

    #Check the sdn logs on pod node
    Given I use the "<%= pod.node_name %>" node
    When I get the networking components logs of the node since "90s" ago
    And the output should not contain "may be offline"

  # @author huirwang@redhat.com
  # @case_id OCP-25640
  @admin
  @destructive
  Scenario: Should be able to access to the service's externalIP with egressIP
    Given I have a project
    Given I store the schedulable nodes in the :nodes clipboard
    And the Internal IP of node "<%= cb.nodes[0].name %>" is stored in the :hostip clipboard

    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["<%= cb.hostip %>/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs": null}}}} |
    """

    # Create a svc with externalIP
    Given I switch to the first user
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %> |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready

    # Patch egressIP to the node
    Given the valid egress IP is added to the node

    # Patch egressIP to a new project
    Given I create a new project
    And I have a pod-for-ping in the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # Curl externalIP:portnumber from project patched egressIP should pass
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello-OpenShift-1 http-8080 |
