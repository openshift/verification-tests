Feature: SDN related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-10025
  @admin
  @destructive
  Scenario: kubelet proxy could change to userspace mode
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
  Scenario: iptables rules will be repaired automatically once it gets destroyed
    Given I select a random node's host
    And the node iptables config is verified
    And the node service is restarted on the host after scenario

    Given the node standard iptables rules are removed
    Given 35 seconds have passed
    Given the node iptables config is verified

  # @author hongli@redhat.com
  # @case_id OCP-13847
  @admin
  Scenario: an empty OPENSHIFT-ADMIN-OUTPUT-RULES chain is created in filter table at startup
    Given the master version >= "3.6"
    Given I have a project
    Given I have a pod-for-ping in the project
    Then evaluation of `pod.node_name` is stored in the :node_name clipboard

    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | iptables | -S | -t | filter |
    Then the step should succeed
    And the output should contain:
      | -N OPENSHIFT-ADMIN-OUTPUT-RULES |
      | -A FORWARD -i tun0 ! -o tun0 -m comment --comment "administrator overrides" -j OPENSHIFT-ADMIN-OUTPUT-RULES |

  # @author yadu@redhat.com
  # @case_id OCP-15251
  @admin
  @destructive
  Scenario: net.ipv4.ip_forward should be always enabled on node service startup
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
  Scenario: The openflow list will be cleaned after deleted the node
    Given environment has at least 2 schedulable nodes
    And I store the schedulable workers in the :nodes clipboard
    Given I switch to cluster admin pseudo user

    # get node_1's host IP and save to clipboard
    Given I use the "<%= cb.nodes[1].name %>" node
    And the node network is verified
    And the node service is verified
    And I register clean-up steps:
    """
    Given I wait for the networking components of the node to become ready
    """
    And I store the node "<%= cb.nodes[1].name %>" YAML to the clipboard
    And the node labels are restored after scenario
    And the node service is restarted on the host after scenario
    And evaluation of `host_subnet(cb.nodes[1].name).ip` is stored in the :hostip clipboard
    # do this first
    And the node in the clipboard is restored from YAML after scenario

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
  Scenario: should not show "No such device" message when run "ovs-vsctl show" command
    Given I have a project
    And I have a pod-for-ping in the project
    And evaluation of `pod.node_name` is stored in the :node_name clipboard
    When I run the :delete client command with:
      | object_type       | pods      |
      | object_name_or_id | hello-pod |
    Then the step should succeed
    Given I wait for the resource "pod" named "hello-pod" to disappear
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | ovs-vsctl | show |
    Then the step should succeed
    And the output should not contain "No such device"

  # @author anusaxen@redhat.com
  # @case_id OCP-23543
  @admin
  Scenario: The iptables binary and rules on sdn containers should be the same as host
    Given I select a random node's host
    When I run commands on the host:
      | iptables-save --version |
    Then the step should succeed
    And evaluation of `@result[:response].scan(/\d\.\d.\d/)` is stored in the :iptables_version_host clipboard
    #Comparing host and sdn container version for iptables binary
    When I run command on the node's sdn pod:
      | iptables-save | --version |
    Then the step should succeed
    And evaluation of `@result[:response].scan(/\d\.\d.\d/)` is stored in the :iptables_version_pod clipboard
    Then the expression should be true> cb.iptables_version_host==cb.iptables_version_pod

    When I run commands on the host:
      | iptables -S \| wc -l |
    Then the step should succeed
    And evaluation of `@result[:response].split("\n")[0]` is stored in the :host_rules clipboard
    #Comparing host and sdn container rules for iptables
    When I run command on the node's sdn pod:
      | bash | -c | iptables -S \| wc -l |
    Then the step should succeed
    And evaluation of `@result[:response].split("\n")[0]` is stored in the :sdn_pod_rules clipboard
    Then the expression should be true> cb.host_rules==cb.sdn_pod_rules
    
  # @author huirwang@redhat.com
  # @case_id OCP-25707
  @admin
  Scenario: ovs-vswitchd process must be running on all ovs pods
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    And all existing pods are ready with labels:
      | app=ovs |
    When I run cmds on all ovs pods:
      | bash | -c | pgrep ovs-vswitchd |
    Then the step should succeed

  # @author huirwang@redhat.com
  # @case_id OCP-25706
  # @bug_id 1669311
  @admin
  @destructive
  Scenario: Killing ovs process should not put sdn and ovs pods in bad shape
    Given I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/networking/list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).node_name` is stored in the :node_name clipboard
    And evaluation of `pod(0).ip` is stored in the :pod1_ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2_name clipboard

    # Kill ovs process
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | bash | -c | pgrep ovs-vswitchd |
    Then the step should succeed
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | bash | -c | pgrep ovs-vswitchd \| xargs kill -9 |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    And all pods in the project are ready
    """

    #Check sdn works
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2_name%>" pod:
      | curl | <%= cb.pod1_ip%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    """
    
  # @author weliang@redhat.com	
  # @case_id OCP-27655	
  @admin	
  Scenario: Networking should work on default namespace		
  #Test for bug https://bugzilla.redhat.com/show_bug.cgi?id=1800324 and https://bugzilla.redhat.com/show_bug.cgi?id=1796157	
    Given I switch to cluster admin pseudo user	
    And I use the "default" project	
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/networking/list_for_pods.json" replacing paths:	
      | ["items"][0]["spec"]["replicas"] | 4 |	
    Then the step should succeed	
    And 4 pods become ready with labels:	
      | name=test-pods |	
    And evaluation of `pod(0).name` is stored in the :pod1_name clipboard	
    And evaluation of `pod(0).ip` is stored in the :pod1_ip clipboard	
    And evaluation of `pod(1).ip` is stored in the :pod2_ip clipboard	
    And evaluation of `pod(2).ip` is stored in the :pod3_ip clipboard	
    And evaluation of `pod(3).ip` is stored in the :pod4_ip clipboard	
    And I register clean-up steps:	
    """	
    Given I ensure "test-rc" replicationcontroller is deleted	
    Given I ensure "test-service" service is deleted	
    """	

    When I execute on the "<%= cb.pod1_name %>" pod:	
      | curl | --connect-timeout | 5 | <%= cb.pod1_ip %>:8080 |	
    Then the step should succeed	
    And the output should contain "Hello OpenShift"	
    When I execute on the "<%= cb.pod1_name %>" pod:	
      | curl | --connect-timeout | 5 | <%= cb.pod2_ip %>:8080 |	
    Then the step should succeed	
    And the output should contain "Hello OpenShift"	
    When I execute on the "<%= cb.pod1_name %>" pod:	
      | curl | --connect-timeout | 5 | <%= cb.pod3_ip %>:8080 |	
    Then the step should succeed	
    And the output should contain "Hello OpenShift"	
    When I execute on the "<%= cb.pod1_name %>" pod:	
      | curl | --connect-timeout | 5 | <%= cb.pod4_ip %>:8080 |	
    Then the step should succeed	
    And the output should contain "Hello OpenShift"
    
  # @author anusaxen@redhat.com
  # @case_id OCP-25787
  @admin
  Scenario: Don't write CNI configuration file until ovn-controller has done at least one iteration
    Given the env is using "OVNKubernetes" networkType
    And I store the masters in the :master clipboard
    And I store "<%= cb.master[0].name %>" node's corresponding default networkType pod name in the :ovnkube_pod clipboard
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ovn-kubernetes" project
    #Fetching ovn master pod name to be used later 
    When I run the :get client command with:
      | resource      | pods                                   |
      | fieldSelector | spec.nodeName=<%= cb.master[0].name %> |
      | l             | app=ovnkube-master                     |
      | output        | json                                   |
    Then the step should succeed
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :ovn_master_pod clipboard
    #Checking controller iteration 1. Need to execute under ovn-contoller container 
    When I run the :exec client command with:
      | pod              | <%= cb.ovnkube_pod %> |
      | c                | ovn-controller        |
      | oc_opts_end      |                       |
      | exec_command     | ovn-appctl            |
      | exec_command_arg | -t                    |
      | exec_command_arg | ovn-controller        |
      | exec_command_arg | connection-status     |
    Then the step should succeed
    And the output should contain "connected"
    #Checking controller iteration 2
    When I execute on the "<%= cb.ovn_master_pod %>" pod:
      | bash | -c | ls -l /var/run/ovn/ |
    Then the step should succeed
    And evaluation of `@result[:response].match(/ovn-controller.\d*\.ctl/)[0]` is stored in the :controller_pid_file clipboard
    #Checking controller iteration 3
    When I execute on the "<%= cb.ovn_master_pod %>" pod:
      | bash | -c | ovn-appctl -t /var/run/ovn/<%= cb.controller_pid_file %> connection-status |
    Then the step should succeed
    And the output should contain "connected"
    #Checking controller iteration 4
    When I run command on the "<%= cb.master[0].name %>" node's sdn pod:
      | bash | -c | ovs-ofctl dump-flows br-int \| wc -l |
    Then the step should succeed
    And the expression should be true> @result[:response].match(/\d*/)[0].to_i > 0
    #Checking final iteration post all above iterations passed. In this iteration we expect CNI file to be created
    Given I use the "<%= cb.master[0].name %>" node
    And I run commands on the host:
      | ls -l /var/run/multus/cni/net.d/10-ovn-kubernetes.conf |
    Then the output should contain "10-ovn-kubernetes.conf"

  # @author anusaxen@redhat.com
  # @case_id OCP-25933
  @admin
  Scenario: NetworkManager should consider OVS interfaces as unmanaged
  Given the env is using "OVNKubernetes" networkType
  And I select a random node's host
  And the vxlan tunnel name of node "<%= node.name %>" is stored in the :tunnel_inf_name clipboard
  #bridge interfaces needs to be unmanaged
  Given I run commands on the host:
    | nmcli |
  Then the output should contain:
    | br-int: unmanaged                    |
    | br-local: unmanaged                  |
    | ovn-k8s-gw0: unmanaged               |
    | genev_sys_6081: unmanaged            |
    | <%= cb.tunnel_inf_name %>: unmanaged |
  # And veths ovs interfaces also needs to be unmanaged
  And I run commands on the host:
    | nmcli device \| grep ethernet \| grep -c unmanaged |
  And evaluation of `@result[:response].split("\n")[0]` is stored in the :no_of_unmanaged_veths clipboard
  And I run commands on the host:
    | nmcli \| grep veth \| wc -l |
  And evaluation of `@result[:response].split("\n")[0]` is stored in the :no_of_veths clipboard
  Then the expression should be true> cb.no_of_veths==cb.no_of_unmanaged_veths
