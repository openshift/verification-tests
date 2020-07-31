Feature: OVN related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-32205
  @admin
  Scenario: Thrashing ovnkube master IPAM allocator by creating and deleting various pods on a specific node
    Given the env is using "OVNKubernetes" networkType
    And I store all worker nodes to the :nodes clipboard
    And I have a project
    Given I obtain test data file "networking/generic_test_pod_with_replica.yaml"
    When I run the steps 10 times:
    """
    When I run oc create over "generic_test_pod_with_replica.yaml" replacing paths:
      | ["spec"]["replicas"]                     | 5                       |
      | ["spec"]["template"]["spec"]["nodeName"] | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And 25 pods become ready with labels:
      | name=test-pods |
    Given I run the :delete client command with:
      | object_type       | rc      |
      | object_name_or_id | test-rc |
    Then the step should succeed
    And all existing pods die with labels:
      | name=test-pods |
    """
  # @author anusaxen@redhat.com
  # @case_id OCP-32184
  @admin
  Scenario: ovnkube-masters should allocate pod IP and mac addresses
    Given the env is using "OVNKubernetes" networkType
    And I have a project
    Given I have a pod-for-ping in the project
    Then evaluation of `pod.ip` is stored in the :hello_pod_ip clipboard
    When I execute on the pod:
       | bash | -c | ip a show eth0 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\h+:\h+:\h+:\h+:\h+:\h+/)[0]` is stored in the :hello_pod_mac clipboard
  
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And evaluation of `pod.ip_url` is stored in the :ovn_nb_leader_ip clipboard
    And evaluation of `pod.node_name` is stored in the :ovn_nb_leader_node clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port \| grep "hello-pod" -C 10 |
    Then the step should succeed
    #Make sure addresses doesn;t say dynamic but show ip and mac assigned to the hello-pod and dynamic_addresses field should be empty
    And the output should contain:
      | addresses           : ["<%= cb.hello_pod_mac %> <%= cb.hello_pod_ip %>"] |
      | dynamic_addresses   : []                                                 |

