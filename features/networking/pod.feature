Feature: Pod related networking scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-9747
  @admin
  Scenario: Pod cannot claim UDP port 4789 on the node as part of a port mapping
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
  Scenario: The user created docker container in openshift cluster should have outside network access
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
  Scenario: Container could reach the dns server
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
  Scenario: The openflow list will be cleaned after delete the pods
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
  Scenario: KUBE-HOSTPORTS chain rules won't be flushing when there is no pod with hostPort
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
  Scenario: Check QoS after creating pod
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
      | sh | -c | iperf3 -c <%= cb.iperf_server %> -i 1 -t 12s |
    Then the step should succeed
    And the expression should be true> @result[:response].scan(/[12].[0-9][0-9] Mbits/).size >= 10
    # test the bandwidth limit with qos for ingress
    When I execute on the "<%= cb.iperf_client %>" pod:
      | sh | -c | iperf3 -c <%= cb.iperf_server %> -i 1 -t 12s -R |
    Then the step should succeed
    And the expression should be true> @result[:response].scan(/[45].[0-9][0-9] Mbits/).size >= 10

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

  # @auther anusaxen@redhat.com
  # @case_id OCP-23890
  @admin
  Scenario: A pod with or without hostnetwork cannot access the MCS port 22623 or 22624 on the master
    Given I use the first master host
    #Step to obtain master IP
    And I run commands on the host:
      | hostname -i |
    Then the step should succeed
    And evaluation of `@result[:response].strip` is stored in the :master_ip clipboard
    
    Given I select a random node's host
    Given I have a project
    #pod-for-ping will be a non-hostnetwork pod
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    And I have a pod-for-ping in the project
    And the pod named "hello-pod" becomes ready

    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22624/config/master | -k |
    Then the output should contain "Connection refused"
    
    #hostnetwork-pod will be a hostnetwork pod
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/anuragthehatter/v3-testfiles/master/networking/hostnetwork-pod.json |
      | n | <%= project.name %>                                                                                   |
    Then the pod named "hostnetwork-pod" becomes ready
    #Pods should not access the MCS port 22623 or 22624 on the master
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22624/config/master | -k |
    Then the output should contain "Connection refused"

  # @auther anusaxen@redhat.com
  # @case_id OCP-23891
  @admin
  Scenario: A pod cannot access the MCS port 22623 or 22624 via the SDN/tun0 address of the master
    Given I use the first master host		
    And I run commands on the host:
      | ifconfig tun0 \| grep -w inet \| awk '{print $2}' |
    Then the step should succeed
    And evaluation of `@result[:response].strip` is stored in the :master_tun0_ip clipboard
    
    Given I select a random node's host
    And I have a project
    #pod-for-ping will be a non-hostnetwork pod
    And I have a pod-for-ping in the project
    And the pod named "hello-pod" becomes ready
    #Curl on Master's tun0 IP to make sure connections are blocked to MCS via tun0
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_tun0_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_tun0_ip %>:22624/config/master | -k |
    Then the output should contain "Connection refused"

  # @auther anusaxen@redhat.com
  # @case_id OCP-23892
  @admin
  Scenario: A pod cannot access the MCS via an egress router in http proxy mode
    Given I use the first master host
    #Step to obtain master IP
    And I run commands on the host:
      | hostname -i |
    Then the step should succeed
    And evaluation of `@result[:response].strip` is stored in the :master_ip clipboard
    
    Given I select a random node's host
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    #pod-for-ping will be a non-hotnetwork pod
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/weliang1/Openshift_Networking/master/egress-http-proxy/egress-http-proxy-pod.yaml |
      | n | <%= project.name %>                                                                                   |
    Then the pod named "egress-http-proxy" becomes ready
    #Pod should not access MCS via an egress router pod
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22624/config/master | -k |
    Then the output should contain "Connection refused"

  # @auther anusaxen@redhat.com
  # @case_id OCP-23893
  @admin
  Scenario: A pod in a namespace with an egress IP cannot access the MCS
    Given I use the first master host
    #Step to obtain master IP
    And I run commands on the host:
      | hostname -i |
    Then the step should succeed
    And evaluation of `@result[:response].strip` is stored in the :master_ip clipboard
    
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard
    #add the egress ip to the hostsubnet
    And the valid egress IP is added to the "<%= cb.egress_node %>" node
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard
    # add the egress ip to the project
    When I run the :patch admin command with:
    | resource      | netnamespace                         |
    | resource_name | <%= cb.project %>                    |
    | p             | {"egressIPs":["<%= cb.valid_ip %>"]} |
    | type          | merge                                |
    Then the step should succeed
    #pod-for-ping will be a non-hostnetwork pod
    And I have a pod-for-ping in the project
    And the pod named "hello-pod" becomes ready
    
    #Pod cannot access MCS
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
    When I execute on the pod:
      | curl | -I | https://<%= cb.master_ip %>:22624/config/master | -k |
    Then the output should contain "Connection refused"
