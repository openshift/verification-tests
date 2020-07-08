Feature: Egress-ingress related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-11639
  @admin
  @destructive
  Scenario: EgressNetworkPolicy will not take effect after delete it
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl           |
      | --head         |
      | www.google.com | 
    Then the step should succeed
    And the output should contain "HTTP/1.1 200" 
    Given I obtain test data file "networking/egressnetworkpolicy/limit_policy.json"
    When I run the :create admin command with:
      | f | limit_policy.json |
      | n | <%= project.name %> |
    Then the step should succeed
    Given I select a random node's host 
    When I use the "<%= project.name %>" project
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.google.com |
    Then the step should fail
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy1             |
      | n                 | <%= project.name %> |
    Then the step should succeed
    Given I select a random node's host 
    When I use the "<%= project.name %>" project
    When I execute on the pod:
      | curl           |
      | --head         |
      | www.google.com |
    Then the step should succeed
    And the output should contain "HTTP/1.1 200"

  # @author weliang@redhat.com
  # @case_id OCP-13502
  @admin
  Scenario: Apply different egress network policy in different projects
    Given the env is using multitenant or networkpolicy network
    Given I have a project 
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard
  
    # Create egress policy in project-1
    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy1.json"
    And I replace lines in "dns-egresspolicy1.json":
      | 98.138.0.0/16 | <%= cb.yahoo_ip %>/32 |
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
   
    # Check curl from pod
    When I execute on the pod:
      | curl | --head | yahoo.com |
    Then the step should succeed
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo_ip %> | 
    Then the step should succeed
    
    Given I create a new project
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj2 clipboard
 
    # Create different egress policy in project-2
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | <%= cb.yahoo_ip %>/32 |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj2 %> |
    Then the step should succeed
 
    # Check curl from pod
    When I execute on the pod:
      | curl | --head | yahoo.com |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo_ip %> | 
    Then the step should fail

    # Check egress policy can be deleted in project1
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy-test             |
      | n                 |  <%= cb.proj1 %>    |
    Then the step should succeed
 
    # Check curl from pod after egress policy deleted
    When I execute on the pod:
      | curl | --head | yahoo.com |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo_ip %> | 
    Then the step should fail   

  # @author weliang@redhat.com
  # @case_id OCP-13507
  @admin
  Scenario: The rules of egress network policy are added in openflow
    Given the env is using multitenant or networkpolicy network
    Given I have a project 
    And evaluation of `project.name` is stored in the :proj1 clipboard
 
    # Create egress policy in project-1
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy1.json"
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
 
    # Check egress rule added in openflow
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :node_name clipboard
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 |
    And the output should contain:
      | nw_dst=98.138.0.0/16 actions=drop |

    # Check egress policy can be deleted
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy-test             |
      | n                 |  <%= cb.proj1 %>    |
    Then the step should succeed

    # Check egress rule deleted in openflow
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :node_name clipboard
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 |
    And the output should not contain:
      | nw_dst=98.138.0.0/16 actions=drop |


  # @author weliang@redhat.com
  # @case_id OCP-13509
  @admin
  Scenario: Egress network policy use dnsname with multiple ipv4 addresses
    Given the env is using multitenant or networkpolicy network
    Given I have a project  
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com", multi: true)` is stored in the :yahoo clipboard
    Then the expression should be true> cb.yahoo.size >= 3

    # Create egress policy 
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    When I run the :create admin command with:
      | f | dns-egresspolicy2.json|
      | n | <%= cb.proj1 %> |
    Then the step should succeed
 
    # Check curl from pod
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo[0] %> |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo[1] %> |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | <%= cb.yahoo[2] %> |
    Then the step should fail 

  # @author weliang@redhat.com
  # @case_id OCP-15005
  @admin
  Scenario: Service with a DNS name can not by pass Egressnetworkpolicy with that DNS name	
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard

    # Create egress policy to deny www.test.com
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
      | yahoo.com | www.test.com |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
    
    # Create a service with a "externalname"
    Given I obtain test data file "networking/service-externalName.json"
    When I run the :create admin command with:
      | f | service-externalName.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed 
    
    # Check curl from pod
    When I execute on the pod:
      | curl | --head | www.test.com |
    Then the step should fail

    # Delete egress network policy
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy-test         |
      | n                 | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | egressnetworkpolicy |
      | deleted             |
    
    # Create egress policy to allow www.test.com
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | --head | www.test.com |    
    Then the step should succeed

  # @author weliang@redhat.com
  # @case_id OCP-15017
  @admin
  Scenario: Add nodes local IP address to OVS rules for egressnetworkpolicy
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    And evaluation of `pod('hello-pod').node_ip(user: user)` is stored in the :hostip clipboard
    And evaluation of `project.name` is stored in the :proj1 clipboard
    And evaluation of `pod.name` is stored in the :pod1 clipboard

    # Check egress rule added in openflow
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :node_name clipboard
    And evaluation of `host_subnet(cb.node_name).ip` is stored in the :hostip clipboard

    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 |
    And the output should contain:
      |tcp,nw_dst=<%= cb.hostip %>,tp_dst=53|
      |udp,nw_dst=<%= cb.hostip %>,tp_dst=53|


    # Create egress policy to allow www.baidu.com
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy1.json"
    And I replace lines in "dns-egresspolicy1.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
      | yahoo.com | www.baidu.com |
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed

    Given I wait up to 10 seconds for the steps to pass:
    """
    When I run command on the "<%= cb.node_name %>" node's sdn pod:
      | ovs-ofctl| -O | openflow13 | dump-flows | br0 | table=101 |
    And the output should contain:
      | actions=drop |
    """
    # Check curl from pod
    Given I use the "<%= cb.proj1 %>" project
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | --head | www.cisco.com |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | www.baidu.com |
    Then the step should succeed

  # @author huirwang@redhat.com
  # @case_id OCP-13506
  @admin
  Scenario: Update different dnsname in same egress network policy
    Given I have a project
    Given I have a pod-for-ping in the project

    # Create egressnetworkpolicy to deny www.test.com
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy4.json"
    When I run oc create over "dns-egresspolicy4.json" replacing paths:
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.test.com |
    Then the step should succeed

    # Access to www.test.com fail
    When I execute on the pod:
      | curl |  -s | --connect-timeout | 5 | www.test.com |
    Then the step should fail
    And admin ensures "policy-test" egress_network_policy is deleted

    # Create egressnetworkpolicy to deny another domain name www.test1.com
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy4.json"
    When I run oc create over "dns-egresspolicy4.json" replacing paths:
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.test1.com |
    Then the step should succeed

    When I execute on the pod:
      | curl |  -s | --connect-timeout | 5 | www.test1.com |
    Then the step should fail
    When I execute on the pod:
      | curl | --head | www.test.com |
    Then the step should succeed

  # @author huirwang@redhat.com
  # @case_id OCP-19615
  @admin
  Scenario: Iptables should be updated with correct endpoints when egress DNS policy was used
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And 1 pods become ready with labels:
      | name=test-pods |
    And evaluation of `service("test-service").url` is stored in the :service_url clipboard
    And I wait for the "test-service" service to become ready

    # Create egress network policy
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy1.json"
    When I run the :create admin command with:
      | f | dns-egresspolicy1.json|
      | n | <%= project.name %>                                                              |
    Then the step should succeed

    #Update egress network policy for more than one time
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    And as admin I successfully merge patch resource "egressnetworkpolicy.network.openshift.io/policy-test" with:
      |{"spec":{"egress":[{"type":"Allow","to":{"dnsName":"test1.com"}}]}}|
    And as admin I successfully merge patch resource "egressnetworkpolicy.network.openshift.io/policy-test" with:
      |{"spec":{"egress":[{"type":"Allow","to":{"dnsName":"test2.com"}}]}}|

    #recreate the pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 0                      |
    And I wait until number of replicas match "0" for replicationController "test-rc"
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 1                      |
    And I wait until number of replicas match "1" for replicationController "test-rc"

    #Curl the service should be successful
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | -k | <%= cb.service_url %> |
    Then the output should contain:
      | Hello OpenShift |
