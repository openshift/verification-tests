Feature: Egress-ingress related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-11639
  @admin
  @destructive
  Scenario: OCP-11639 EgressNetworkPolicy will not take effect after delete it
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl           |
      | --head         |
      | www.google.com | 
    Then the step should succeed
    And the output should contain "HTTP/1.1 200" 
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egressnetworkpolicy/limit_policy.json |
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
  Scenario: OCP-13502 Apply different egress network policy in different projects
    Given the env is using multitenant or networkpolicy network
    Given I have a project 
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard
  
    # Create egress policy in project-1
    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy1.json"
    And I replace lines in "dns-egresspolicy1.json":
      | 98.138.0.0/16 | <%= cb.yahoo_ip %>/32 |
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
   
    # Check ping from pod
    When I execute on the pod:
      | ping | -c1 | -W2 | yahoo.com |
    Then the step should succeed
    When I execute on the pod:
      | ping | -c1 | -W2 | <%= cb.yahoo_ip %> | 
    Then the step should succeed
    
    Given I create a new project
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj2 clipboard
 
    # Create different egress policy in project-2
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | <%= cb.yahoo_ip %>/32 |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj2 %> |
    Then the step should succeed
 
    # Check ping from pod
    When I execute on the pod:
      | ping | -c1 | -W2 | yahoo.com |
    Then the step should fail
    When I execute on the pod:
      | ping | -c1 | -W2 | <%= cb.yahoo_ip %> | 
    Then the step should fail

    # Check egress policy can be deleted in project1
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy-test             |
      | n                 |  <%= cb.proj1 %>    |
    Then the step should succeed
 
    # Check ping from pod after egress policy deleted
    When I execute on the pod:
      | ping | -c1 | -W2 | yahoo.com |
    Then the step should fail
    When I execute on the pod:
      | ping | -c1 | -W2 | <%= cb.yahoo_ip %> | 
    Then the step should fail   

  # @author weliang@redhat.com
  # @case_id OCP-13507
  @admin
  Scenario: OCP-13507 The rules of egress network policy are added in openflow
    Given the env is using multitenant or networkpolicy network
    Given I have a project 
    And evaluation of `project.name` is stored in the :proj1 clipboard
 
    # Create egress policy in project-1
    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy1.json"
    And I replace lines in "dns-egresspolicy1.json":
      | 98.138.0.0/16 | <%= cb.yahoo_ip %>/32 |
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
 
    # Check egress rule added in openflow
    Given I select a random node's host
    When I run the ovs commands on the host:
       | ovs-ofctl dump-flows br0 -O openflow13 \| grep <%= cb.yahoo_ip %> |
    And the output should contain 1 times:
      | actions=drop |

    # Check egress policy can be deleted
    When I run the :delete admin command with:
      | object_type       | egressnetworkpolicy |
      | object_name_or_id | policy-test             |
      | n                 |  <%= cb.proj1 %>    |
    Then the step should succeed

    # Check egress rule deleted in openflow
    Given I select a random node's host
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 \| grep <%= cb.yahoo_ip %> |
    And the output should not contain:
      | actions=drop |

  # @author weliang@redhat.com
  # @case_id OCP-13509
  @admin
  Scenario: OCP-13509 Egress network policy use dnsname with multiple ipv4 addresses
    Given the env is using multitenant or networkpolicy network
    Given I have a project  
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    And evaluation of `BushSlicer::Common::Net.dns_lookup("www.yahoo.com", multi: true)` is stored in the :yahoo clipboard
    Then the expression should be true> cb.yahoo.size >= 3

    # Create egress policy 
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | yahoo.com | www.yahoo.com |
    When I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
 
    # Check ping from pod
    When I execute on the pod:
      | ping | -c1 | -W2 | <%= cb.yahoo[0] %> |
    Then the step should fail
    When I execute on the pod:
      | ping | -c1 | -W2 | <%= cb.yahoo[1] %> |
    Then the step should fail
    When I execute on the pod:
     | ping | -c1 | -W2 | <%= cb.yahoo[2] %> |
    Then the step should fail 

  # @author weliang@redhat.com
  # @case_id OCP-15005
  @admin
  Scenario: OCP-15005 Service with a DNS name can not by pass Egressnetworkpolicy with that DNS name	
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard

    # Create egress policy to deny www.test.com
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
      | yahoo.com | www.test.com |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed
    
    # Create a service with a "externalname"
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/service-externalName.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed 
    
    # Check curl from pod
    When I execute on the pod:
      | curl |-ILs  | www.test.com |
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
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | -ILs  | www.test.com |    
    Then the step should succeed

  # @author weliang@redhat.com
  # @case_id OCP-15017
  @admin
  Scenario: OCP-15017 Add nodes local IP address to OVS rules for egressnetworkpolicy
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    And evaluation of `pod('hello-pod').node_ip(user: user)` is stored in the :hostip clipboard
    And evaluation of `project.name` is stored in the :proj1 clipboard

    # Check egress rule added in openflow
    Given I use the "<%= pod.node_name(user: user) %>" node
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 \| grep tcp \| grep tp_dst=53 |
    And the output should contain 1 times:
      | nw_dst=<%= cb.hostip %> |
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 \| grep udp \| grep tp_dst=53 |
    And the output should contain 1 times:
      | nw_dst=<%= cb.hostip %> |

    # Create egress policy to allow www.baidu.com
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/dns-egresspolicy1.json"
    And I replace lines in "dns-egresspolicy1.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
      | yahoo.com | www.baidu.com |
    And I run the :create admin command with:
      | f | dns-egresspolicy1.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed

    Given I wait up to 10 seconds for the steps to pass:
    """
    When I run the ovs commands on the host:
      | ovs-ofctl dump-flows br0 -O openflow13 \| grep table=101 |
    And the output should contain:
      | actions=drop |
    """
    # Check ping from pod
    When I execute on the pod:
      | ping | -c2 | -W2 | www.cisco.com |
    Then the step should fail
    When I execute on the pod:
      | ping | -c2 | -W2 | www.baidu.com |
    Then the step should succeed

