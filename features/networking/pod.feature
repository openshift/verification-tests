Feature: Pod related networking scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-9747
  @admin
  Scenario: OCP-9747 Pod cannot claim UDP port 4789 on the node as part of a port mapping
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod_with_udp_port_4789.json |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :pending
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource      | pod   |
    Then the output should contain "address already in use"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-9802
  @admin
  Scenario: OCP-9802 The user created docker container in openshift cluster should have outside network access
    Given I select a random node's host
    And I run commands on the host:
      | docker run -td --name=test-container bmeng/hello-openshift |
    Then the step should succeed
    And I register clean-up steps:
    """
    I run commands on the host:
      | docker rm -f test-container |
    the step should succeed
    """
    When I run commands on the host:
      | docker exec test-container curl -sIL www.redhat.com |
    Then the step should succeed
    And the output should contain "HTTP/1.1 200 OK"

  # @author yadu@redhat.com
  # @case_id OCP-10031
  @smoke
  Scenario: OCP-10031 Container could reach the dns server
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/tc528410/tc_528410_pod.json |
    And the pod named "hello-pod" becomes ready
    And I run the steps 20 times:
    """
    Given I execute on the pod:
      | getent | hosts | google.com |
    Then the step should succeed
    And the output should contain "google.com"
    """

  # @author yadu@redhat.com
  # @case_id OCP-14986
  @admin
  Scenario: OCP-14986 The openflow list will be cleaned after delete the pods
    Given I have a project
    Given I have a pod-for-ping in the project
    Then I use the "<%= pod.node_name(user: user) %>" node
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should contain:
      | <%=cb.pod_ip %> |
    When I run the :delete client command with:
      | object_type       | pod       |
      | object_name_or_id | hello-pod |
    Then the step should succeed
    Given I select a random node's host
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should not contain:
      | <%=cb.pod_ip %> |

  # @author yadu@redhat.com
  # @case_id OCP-16729
  @admin
  @destructive
  Scenario: OCP-16729 KUBE-HOSTPORTS chain rules won't be flushing when there is no pod with hostPort
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    Given I store the schedulable nodes in the :nodes clipboard
    Given I select a random node's host
    # Add a fake rule
    Given I register clean-up steps:
    """
    When I run commands on the host:
      | iptables -t nat -D KUBE-HOSTPORTS -p tcp --dport 110 -j ACCEPT |
    """
    When I run commands on the host:
      | iptables -t nat -A KUBE-HOSTPORTS -p tcp --dport 110 -j ACCEPT |
    Then the step should succeed
    When I run commands on the host:
      | iptables-save \| grep HOSTPORT |
    Then the step should succeed
    And the output should contain:
      | -A PREROUTING -m comment --comment "kube hostport portals" -m addrtype --dst-type LOCAL -j KUBE-HOSTPORTS |
      | -A OUTPUT -m comment --comment "kube hostport portals" -m addrtype --dst-type LOCAL -j KUBE-HOSTPORTS     |
      | -A KUBE-HOSTPORTS -p tcp -m tcp --dport 110 -j ACCEPT |
    #Create a normal pod without hostport
    Given I switch to the first user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/scheduler/pod_with_nodename.json" replacing paths:
      | ["spec"]["nodeName"] | <%= node.name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=nodename-pod |
    Given 30 seconds have passed
    When I run commands on the host:
      | iptables-save \| grep HOSTPORT |
    Then the step should succeed
    #The rule won't be flushing when there is no pod with hostport
    And the output should contain:
      | -A PREROUTING -m comment --comment "kube hostport portals" -m addrtype --dst-type LOCAL -j KUBE-HOSTPORTS |
      | -A OUTPUT -m comment --comment "kube hostport portals" -m addrtype --dst-type LOCAL -j KUBE-HOSTPORTS     |
      | -A KUBE-HOSTPORTS -p tcp -m tcp --dport 110 -j ACCEPT |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/nodeport_pod.json" replacing paths:
      | ["spec"]["template"]["spec"]["nodeName"] | <%= node.name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=rc-test |
    When I run commands on the host:
      | iptables-save \| grep HOSTPORT |
    Then the step should succeed
    And the output should contain:
      | hostport 6061" -m tcp --dport 6061 |
    # The fake rule disappeared after creating a pod with hostport
    And the output should not contain:
      | -A KUBE-HOSTPORTS -p tcp --dport 110 -j ACCEPT |

  # @auther bmeng@redhat.com
  # @case_id OCP-10817
  @admin
  Scenario: OCP-10817 Check QoS after creating pod
    Given I have a project
    # setup iperf server to receive the traffic
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/qos/iperf-server.json |
    Then the step should succeed
    And the pod named "iperf-server" becomes ready
    And evaluation of `pod.ip` is stored in the :iperf_server clipboard

    # setup iperf client to send traffic to server with qos configured
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/qos/iperf-rc.json" replacing paths:
      | ["spec"]["template"]["metadata"]["annotations"]["kubernetes.io/ingress-bandwidth"] | 5M |
      | ["spec"]["template"]["metadata"]["annotations"]["kubernetes.io/egress-bandwidth"] | 2M |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=iperf-pods |
    And evaluation of `pod.name` is stored in the :iperf_client clipboard
    And evaluation of `pod.node_name` is stored in the :iperf_client_node clipboard

    # check the ovs port and interface for the qos availibility
    Given I use the "<%= cb.iperf_client_node %>" node
    When I run the ovs commands on the host:
      | ovs-vsctl list qos |
    Then the step should succeed
    And the output should contain "max-rate="5000000""
    When I run the ovs commands on the host:
      | ovs-vsctl list interface \| grep ingress |
    Then the step should succeed
    And the output should contain "ingress_policing_rate: 1953"

    # test the bandwidth limit with qos for egress
    When I execute on the "<%= cb.iperf_client %>" pod:
      | sh | -c | iperf3 -c <%= cb.iperf_server %> -i 1 -t 12s \| grep "1.99 Mbits" |
    Then the step should succeed
    And the expression should be true> @result[:response].lines.count >= 6
    # test the bandwidth limit with qos for ingress
    When I execute on the "<%= cb.iperf_client %>" pod:
      | sh | -c | iperf3 -c <%= cb.iperf_server %> -i 1 -t 12s -R \| grep "4.98 Mbits" |
    Then the step should succeed
    And the expression should be true> @result[:response].lines.count >= 6

    # remove the qos pod and check if the ovs qos configurations are removed
    When I run the :delete client command with:
      | object_type | replicationcontrollers |
      | object_name_or_id | iperf-rc |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= cb.iperf_client %>" to disappear

    When I run the ovs commands on the host:
      | ovs-vsctl list qos |
    Then the step should succeed
    And the output should not contain "max-rate="5000000""
    When I run the ovs commands on the host:
      | ovs-vsctl list interface \| grep ingress |
    Then the step should succeed
    And the output should not contain "ingress_policing_rate: 1953"
 
  # @author anusaxen@redhat.com
  # @case_id OCP-19810
  @admin
  Scenario: OCP-19810 Conntrack rule for UDP traffic should be removed when the pod for NodePort service deleted
    Given the master version <= "3.11"
    Given I store the schedulable nodes in the :nodes clipboard
    Given I use the "<%= cb.nodes[0].name %>" node
    And I have a project

    #Creating a pod with udp listener on a scedulable node
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod_with_udp_port_listener.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=udp-pods |
    And evaluation of `pod` is stored in the :host_pod1 clipboard
    And evaluation of `host_subnet(cb.nodes[0].name).ip` is stored in the :node_ip clipboard

    #Using node port to expose the service on port 8080 on the node IP address
    When I run the :expose client command with:
      | resource      | pod                      |
      | resource_name | <%= cb.host_pod1.name %> |
      | type          | NodePort                 |
      | port          | 8080                     |
      | protocol      | UDP                      |
    Then the step should succeed
    
    When I run the :get client command with:
      | resource | service                                       |
      | output   | jsonpath='{.items[*].spec.ports[*].nodePort}' |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :nodeport clipboard
    
    #Creating a simple client pod to generate traffic from it towards the exposed node IP address
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/aosqe-pod-for-ping.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod` is stored in the :client_pod clipboard
    
    # 'yes' command will send a character "h" continously for 3 seconds to /dev/udp on listener where the node is listening for udp traffic on exposed nodeport. The 3 seconds mechanism will create an Assured
    #  entry which will give us enough time to validate upcoming steps
    When I run the :exec background client command with:
      | pod              | <%= cb.client_pod.name %>                             |
      | oc_opts_end      |                                                       |
      | exec_command     | bash                                                  |
      | exec_command_arg | -c                                                    |
      | exec_command_arg | yes "h">/dev/udp/<%= cb.node_ip %>/<%= cb.nodeport %> |
    Given 3 seconds have passed
    And I terminate last background process
    When I run commands on the host:
      | conntrack -L \| grep <%= cb.nodeport %> |
    Then the step should succeed
    And the output should contain:
      |<%= cb.host_pod1.ip %>|

    #Deleting the udp listener pod which will trigger a new udp listener pod with new IP
    When I run the :delete client command with:
      | object_type       | pod                      |
      | object_name_or_id | <%= cb.host_pod1.name %> |
    Given a pod becomes ready with labels:
      | name=udp-pods |
    And evaluation of `pod` is stored in the :host_pod2 clipboard

    # 'yes' command will send a character "h" continously for 3 seconds to /dev/udp on listener where the node is listening for udp traffic on exposed nodeport. The 3 seconds mechanism will create an Assured
    #  entry which will give us enough time to validate upcoming steps
    When I run the :exec background client command with:
      | pod              | <%= cb.client_pod.name %>                             |
      | oc_opts_end      |                                                       |
      | exec_command     | bash                                                  |
      | exec_command_arg | -c                                                    |
      | exec_command_arg | yes "h">/dev/udp/<%= cb.node_ip %>/<%= cb.nodeport %> |
    Given 3 seconds have passed
    And I terminate last background process
    
    #Making sure that the conntrack table should not contain old deleted udp listener pod IP entries but new pod one's
    When I run commands on the host:
      | conntrack -L \| grep <%= cb.nodeport %> |
    Then the output should contain "<%= cb.host_pod2.ip %>"
    And the output should not contain "<%= cb.host_pod1.ip %>"
