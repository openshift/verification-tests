Feature: OVN Egress IP related features

  # @author huirwang@redhat.com
  # @case_id OCP-33618
  @admin
  @destructive
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
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create second project and pods in it,add label to the namespace
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj2 %>     |
      | key_val  | og=dev              |
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
      | key_val  | og=qe               |
    Then the step should succeed
    And I have a pod-for-ping in the project

    #Create second project and pods in it,add label to the namespace
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= cb.proj2 %>     |
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
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
      | key_val  | og-                 |
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
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
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
      | key_val  | og=qe               |
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
