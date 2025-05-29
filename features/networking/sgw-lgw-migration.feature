Feature: SGW<->LGW migration related scenarios

  
  # @author anusaxen@redhat.com
  # @case_id OCP-47561
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9
  @admin
  @destructive
  @network-ovnkubernetes
  @vsphere-ipi
  @noproxy @connected
  @vsphere-upi
  @amd64
  @hypershift-hosted
  Scenario: OCP-47561:SDN SGW <-> LGW migration scenario for vsphere platform
    Given the env is using "OVNKubernetes" networkType

    ######## Prepare Data Pre Migration for multiple use cases############

    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master0_ip clipboard
    And the Internal IP of node "<%= cb.masters[1].name %>" is stored in the :master1_ip clipboard
    And evaluation of `rand(30000..32767)` is stored in the :port clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod.node_ip` is stored in the :hostip clipboard
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"]  | <%= cb.port %> |
      | ["spec"]["externalTrafficPolicy"] | Local          |
    Then the step should succeed

    #OCP-37496- EgressFirewall sould take effect
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I have a pod-for-ping in the project
    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy4.yaml"
    And I run oc create as admin over "egressfirewall-policy4.yaml" replacing paths:
      | ["spec"]["egress"][0]["type"]          | Deny            |
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.redhat.com  |
      | ["metadata"]["namespace"]              | <%= cb.proj2 %> |
    Then the step should succeed

    #OCP-33618- EgressIP works for the pod in the matched namespace when only configure namespaceSelector
    Given I save ipecho url to the clipboard
    And I store the schedulable workers in the :workers clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.workers[0].name %>" node
    Given I store a random unused IP address from the reserved range to the clipboard
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj3 clipboard
    When I run the :label admin command with:
      | resource | namespace        |
      | name     | <%= cb.proj3 %>  |
      | key_val  | org=qe           |
    Then the step should succeed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(-1).name` is stored in the :egressip_pod1 clipboard
    And admin ensures "egressip" egress_ip is deleted after scenario
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    #Switching cluster to another gateway mode and reverting back to original in clean up
    Given the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    And I switch the ovn gateway mode on this cluster
    And I register clean-up steps:
    """
    I switch the ovn gateway mode on this cluster
    And the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    """
    
    ######## Check Data Post Migration for multiple use cases############
    
    
    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I use the "<%= cb.masters[1].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.hostip %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.master0_ip %>:<%= cb.port %> |
    Then the step should fail
    And the output should not contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.master1_ip %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.proj1 %>" project
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.hostip %>:<%= cb.port %> |
    Then the step should fail

    #OCP-37496- EgressFirewall sould take effect
    Given I use the "<%= cb.proj2 %>" project
    When I execute on the "hello-pod" pod:
      | curl | --connect-timeout | 5 | --head | www.redhat.com |
    Then the step should fail

    #OCP-33618- EgressIP works for the pod in the matched namespace when only configure namespaceSelector
    Given I use the "<%= cb.proj3 %>" project
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.egressip_pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    """
 
  # @author anusaxen@redhat.com
  # @case_id OCP-47641
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9
  @admin
  @destructive
  @network-ovnkubernetes
  @baremetal-upi
  @proxy @noproxy @disconnected @connected
  @amd64
  @hypershift-hosted
  Scenario: OCP-47641:SDN SGW <-> LGW migration scenario for BM platform
    Given the env is using "OVNKubernetes" networkType

    ######## Prepare Data Pre Migration for multiple use cases############
    
    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master0_ip clipboard
    And the Internal IP of node "<%= cb.masters[1].name %>" is stored in the :master1_ip clipboard
    And evaluation of `rand(30000..32767)` is stored in the :port clipboard
    Given I have a project
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod.node_ip` is stored in the :hostip clipboard
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"]  | <%= cb.port %> |
      | ["spec"]["externalTrafficPolicy"] | Local          |
    Then the step should succeed
    
    
    #Switching cluster to another gateway mode and reverting back to original in clean up
    Given the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    And I switch the ovn gateway mode on this cluster
    And I register clean-up steps:
    """
    I switch the ovn gateway mode on this cluster
    And the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    """
    
    ######## Check Data Post Migration for multiple use cases############
    
    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I use the "<%= cb.masters[1].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master0_ip %>]:<%= cb.port %> |
    Then the step should fail
    And the output should not contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master1_ip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    Then the step should fail

  # @author weliang@redhat.com
  # @case_id OCP-48066
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10
  @admin
  @destructive
  @network-ovnkubernetes
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @amd64
  @hypershift-hosted
  Scenario: OCP-48066:SDN SGW <-> LGW migration scenarios for externalIP
    Given the env is using "OVNKubernetes" networkType
    ######## Prepare Data Pre Migration ############
    #OCP-24669 - externalIP defined in service with set ExternalIP in allowedCIDRs
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
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
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %> |
    Then the step should succeed
    """
    # Create a pod
    Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready
    # Curl externalIP:portnumber should pass
    Given I store the masters in the :masters clipboard
	  Given I use the "<%= cb.masters[0].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.masters[1].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

    # Switching cluster to another gateway mode and reverting back to original in clean up
    Given the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    And I switch the ovn gateway mode on this cluster
    And I register clean-up steps:
    """
    I switch the ovn gateway mode on this cluster
    And the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    """
    
    ######## Check Data Post Migration ############   
    #OCP-24669 - externalIP defined in service with set ExternalIP in allowedCIDRs
    Given I use the "<%= cb.masters[0].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.masters[1].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
