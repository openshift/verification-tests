Feature: OVN Egress IP related features

  # @author huirwang@redhat.com
  # @case_id OCP-33618
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @upgrade-sanity
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: EgressIP works for all pods in the matched namespace when only configure namespaceSelector
    Given I save ipecho url to the clipboard
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.egress_node %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create new namespace and pods in it
    Given I have a project
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
      | key_val  | org=qe              |
    Then the step should succeed

    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard
    And evaluation of `pod(2).name` is stored in the :pod2 clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Create some more pods after the egressip object created
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 3                      |
    Then the step should succeed
    Given 3 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(3).name` is stored in the :pod3 clipboard

    # Check source ip is egress ip
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-33723
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @upgrade-sanity
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: Multiple EgressIP objects can have multiple Egress IPs
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[1].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create first project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create second project and pods in it,add label to the namespace
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj2 %>     |
      | key_val  | org=dev             |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create first egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip2.yaml"
    And I replace lines in "egressip2.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | 172.31.249.228 | "<%= cb.valid_ips[1] %>" |
    And I run the :create admin command with:
      | f | egressip2.yaml |
    Then the step should succeed
    And admin ensures "egressip2" egress_ip is deleted after scenario

    #Create second egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip2.yaml"
    And I replace lines in "egressip2.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[2] %>" |
      | 172.31.249.228 | "<%= cb.valid_ips[3] %>" |
      | egressip2      | "egressip3"              |
      | qe             | "dev"                    |
    And I run the :create admin command with:
      | f | egressip2.yaml |
    Then the step should succeed
    And admin ensures "egressip3" egress_ip is deleted after scenario

    # Check source ip is one of egress ips in the matched egress ip object
    When I execute on the "hello-pod" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the expression should be true> %w( <%= cb.valid_ips[2] %> <%= cb.valid_ips[3] %> ).include?@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]
    Given I use the "<%= cb.proj1 %>" project
    When I execute on the "hello-pod" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the expression should be true> %w( <%= cb.valid_ips[0] %> <%= cb.valid_ips[1] %> ).include?@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]

  # @author huirwang@redhat.com
  # @case_id OCP-33641
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @upgrade-sanity
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: Multi-project can share same EgressIP
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create first project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create second project and pods in it,add label to the namespace
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj2 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Check source ip is egress ip from both projects
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    Given I use the "<%= cb.proj1 %>" project
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    #Create third project after egress ip object created
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj3 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj3 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    # Check source ip is egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-33699
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: Removed matched labels from project will not use EgressIP
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Check source ip is egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    #Remove label from namespace
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org-                |
    Then the step should succeed

    # Check source ip is not egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should not contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-33700
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: Removed matched labels from pods will not use EgressIP
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace and pod
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project
    When I run the :label admin command with:
      | resource  | pod                    |
      | name      | <%= pod(1).name %>     |
      | key_val   | team=blue              |
      | namespace | <%= cb.proj1 %>        |
    Then the step should succeed

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip3.yaml"
    And I replace lines in "egressip3.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip3.yaml |
    Then the step should succeed
    And admin ensures "egressip3" egress_ip is deleted after scenario

    # Check source ip is egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    #Remove label from pods
    When I run the :label admin command with:
      | resource  | pod                 |
      | name      | <%= pod(1).name %>  |
      | key_val   | team-               |
      | namespace | <%= cb.proj1 %>     |
    Then the step should succeed

    # Check source ip is not egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should not contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-33631
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @upgrade-sanity
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: EgressIP was removed after delete egressIP object
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Check source ip is egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    #Remove egress ip object
    Given admin ensures "egressip" egress_ip is deleted

    # Check source ip is not egress ip
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should not contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-33704
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: After reboot node or reboot OVN services EgressIP still work
    Given I save ipecho url to the clipboard
    Given I store the schedulable workers in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed

    #Make sure the pod located on another node to avoid rebooting the node cause killing the pod
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["nodeName"] | <%= cb.nodes[1].name %> |
      | ["items"][0]["spec"]["replicas"]                     | 1                       |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    #Restart network componets the egress ip node
    Given I use the "<%= cb.nodes[0].name %>" node
    And I restart the network components on the node
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    """

    # Reboot the node which patched egressIP
    Given the host is rebooted and I wait it up to 600 seconds to become available
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-34938
  @admin
  @destructive
  @network-ovnkubernetes
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @aws-ipi
  @vsphere-upi @aws-upi
  @noproxy @connected
  Scenario: Warning event will be triggered if apply EgressIP object but no EgressIP nodes
    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    #Check events
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    Then I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | event                |
    Then the step should succeed
    And the output should contain:
      | no assignable nodes for EgressIP |
    """

  # @author huirwang@redhat.com
  # @case_id OCP-33706
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: The pod located on different node than EgressIP nodes
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create new namespace and pods in it
    Given I have a project
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
      | key_val  | org=qe              |
    Then the step should succeed

    #Specify different node for pod than egressIP node
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["nodeName"] | <%= cb.nodes[1].name %> |
      | ["items"][0]["spec"]["replicas"]                     | 1                       |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Check source ip is egress ip
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    """

  # @author huirwang@redhat.com
  # @case_id OCP-33718
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @qeci
  @noproxy @connected
  Scenario: Deleting EgressIP object and recreating it will work
    Given I save ipecho url to the clipboard

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    And admin ensures "egressip" egress_ip is deleted after scenario

    #Label EgressIP nodes.
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    # Check source ip is egress ip
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    """

    #Remove egress ip object and recreate it
    Given admin ensures "egressip" egress_ip is deleted
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    # Check source ip is egress ip
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-33710
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @network-ovnkubernetes
  @noproxy @connected
  Scenario: An EgressIP object can not have multiple egress IP assignments on the same node
    Given I store the schedulable workers in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create first egress ip object with two EgressIPs
    When I obtain test data file "networking/ovn-egressip/egressip2.yaml"
    And I replace lines in "egressip2.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | 172.31.249.228 | "<%= cb.valid_ips[1] %>" |
    And I run the :create admin command with:
      | f | egressip2.yaml |
    And admin ensures "egressip2" egress_ip is deleted after scenario

    # Check only one IP assigned.
    When I run the :get admin command with:
      | resource       | egressip                    |
      | resource_name  | egressip2                   |
      | o              | jsonpath={.status.items[*]} |
    Then the step should succeed
    And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/).length` is stored in the :egressip_num clipboard
    Then the expression should be true> cb.egressip_num == 1

  # @author huirwang@redhat.com
  # @case_id OCP-33617
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @aws-ipi
  @aws-upi
  @network-ovnkubernetes
  @noproxy @connected
  Scenario: Common user cannot tag the nodes by labelling them as egressIP nodes
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard

    #Label nodes with normal user
    When I run the :label client command with:
      | resource | node                               |
      | name     | <%= cb.egress_node %>              |
      | key_val  | k8s.ovn.org/egress-assignable=true |
    Then the step should fail
    And the output should match:
      | nodes "<%= cb.egress_node %>" is forbidden |

  # @author huirwang@redhat.com
  # @case_id OCP-33719
  @admin
  @destructive
  @network-ovnkubernetes
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @aws-ipi
  @aws-upi
  @noproxy @connected
  Scenario: Any egress IP can only be assigned to one node only
    Given I store the schedulable workers in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node
    And label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[1].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    # Create two egressip objects with same EgressIP
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    And admin ensures "egressip" egress_ip is deleted after scenario

    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | name: egressip | name: egressipnew        |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    And admin ensures "egressipnew" egress_ip is deleted after scenario

    #Check the egressIP can be only assigned to one node.
    When I run the :get admin command with:
      | resource       | egressip                    |
      | resource_name  | egressip                    |
      | o              | jsonpath={.status.items[*]} |
    Then the step should succeed
    And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/).length` is stored in the :egressip_num clipboard
    Then the expression should be true> cb.egressip_num == 1

    When I run the :get admin command with:
      | resource       | egressip                    |
      | resource_name  | egressipnew                 |
      | o              | jsonpath={.status.items[*]} |
    Then the step should succeed
    Then the expression should be true> @result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/).nil?

  # @author huirwang@redhat.com
  # @case_id OCP-44250
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @proxy @noproxy @disconnected @connected
  Scenario: lr-policy-list and snat should be updated correctly after remove pods
    Given I store the schedulable workers in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create first project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=pm              |
    Then the step should succeed

    #Create 10  pods in projects
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 10 |
    Then the step should succeed
    Given 10 pod become ready with labels:
      | name=test-pods |

    #Create an egress ip object
    Given admin ensures "egressip" egress_ip is deleted after scenario
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | qe             | "pm"                     |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    #Scale down CNO to 0 and delete ovnkube-master pods
    Given I register clean-up steps:
    """
    And I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 1                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    """
    # Now scale down CNO pod to 0
    And I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 0                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    And admin ensures "ovnkube-master" ds is deleted from the "openshift-ovn-kubernetes" project
    And admin executes existing pods die with labels:
      | app=ovnkube-master |

    # Now scale down test pods to 1
    Given I run the :scale admin command with:
      | resource | rc                         |
      | name     | test-rc                    |
      | replicas | 1                          |
      | n        | <%= cb.proj1 %>            |
    Then the step should succeed
    Given I use the "<%= cb.proj1 %>" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(-1).ip` is stored in the :pod0ip clipboard

    # Now scale up CNO pod to 1
    Given I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 1                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    # A minimum wait for 30 seconds is tested to reflect CNO deployment to be effective which will then re-spawn ovn pods
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ovn-kubernetes" project
    And a pod becomes ready with labels:  
      | app=ovnkube-master |
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 150 seconds

    # Checking lr-policy-list, no duplicate records, only 1 record left 
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl lr-policy-list ovn_cluster_router  \| grep "100 " \| grep -v inport |
    Then the step should succeed
    And the output should match 1 times:
      | <%= cb.pod0ip %> |
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl lr-policy-list ovn_cluster_router  \| grep "100 " \| grep -v inport \| grep -v <%= cb.pod0ip %> |
    Then the step should fail 
    # Checking snat rules, only 1 running pod related rule is there.
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl --format=csv --no-heading find nat external_ids:name=egressip |
    Then the step should succeed
    And the output should match 1 times:
      | <%= cb.pod0ip %> |
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl --format=csv --no-heading find nat external_ids:name=egressip \| grep -v <%= cb.pod0ip %> |
    Then the step should fail 
    And the output should not contain:
      | name=egressip |

  # @author huirwang@redhat.com
  # @case_id OCP-44251
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi
  @vsphere-upi
  @network-ovnkubernetes
  @proxy @noproxy @disconnected @connected
  Scenario: lr-policy-list and snat should be updated correctly after remove egressip objects 
    Given I store the schedulable workers in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create first project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=pm              |
    Then the step should succeed

    #Create 10  pods in projects
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 10 |
    Then the step should succeed
    Given 10 pod become ready with labels:
      | name=test-pods |

    #Create an egress ip object
    Given admin ensures "egressip" egress_ip is deleted after scenario
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | qe             | "pm"                     |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    #Scale down CNO to 0 and delete ovnkube-master pods
    Given I register clean-up steps:
    """
    And I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 1                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    """
    # Now scale down CNO pod to 0
    And I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 0                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    And admin ensures "ovnkube-master" ds is deleted from the "openshift-ovn-kubernetes" project
    And admin executes existing pods die with labels:
      | app=ovnkube-master |

    # Now delete egressip object 
    Given admin ensures "egressip" egress_ip is deleted

    # Now scale up CNO pod to 1
    Given I run the :scale admin command with:
      | resource | deployment                 |
      | name     | network-operator           |
      | replicas | 1                          |
      | n        | openshift-network-operator |
    Then the step should succeed
    # A minimum wait for 30 seconds is tested to reflect CNO deployment to be effective which will then re-spawn ovn pods
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ovn-kubernetes" project
    And a pod becomes ready with labels:  
      | app=ovnkube-master |
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 150 seconds

    # Checking lr-policy-list,no egressip list 
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl lr-policy-list ovn_cluster_router  \| grep "100 " \| grep -v inport |
    Then the step should fail 
    # Checking snat rules, no egressip rules 
    And admin executes on the pod "northd" container:
      | bash | -c | ovn-nbctl --format=csv --no-heading find nat external_ids:name=egressip |
    Then the step should succeed 
    And the output should not contain:
      | name=egressip |

  # @author huirwang@redhat.com
  # @case_id OCP-42925
  @admin
  @destructive
  @4.11 @4.10 @4.9
  @network-ovnkubernetes
  @vsphere-ipi
  @vsphere-upi
  @qeci
  @proxy @noproxy @disconnected @connected
  Scenario: Traffic is load balanced between egress nodes in OVN cluster
    Given I save ipecho url to the clipboard
    Given I store the schedulable nodes in the :nodes clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[0].name %>" node
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.nodes[1].name %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create a project and pods in it,add label to the namespace
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj1 %>     |
      | key_val  | org=qe              |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip2.yaml"
    And I replace lines in "egressip2.yaml":
      | 172.31.249.227 | "<%= cb.valid_ips[0] %>" |
      | 172.31.249.228 | "<%= cb.valid_ips[1] %>" |
    And I run the :create admin command with:
      | f | egressip2.yaml |
    Then the step should succeed
    And admin ensures "egressip2" egress_ip is deleted after scenario

    # Check egress ip is loadbalanced
    When I execute on the pod:
      | bash | -c | for i in {1..10}; do curl -s --connect-timeout 2 <%= cb.ipecho_url %> ; sleep 2;echo ""; done;  |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ips[1] %>"
    And the output should contain "<%= cb.valid_ips[0] %>"
