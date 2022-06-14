Feature: Egress-ingress related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-11639
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-11639 EgressNetworkPolicy will not take effect after delete it
    Given I have a project
    Given I have a pod-for-ping in the project
    Given I save egress data file directory to the clipboard
    And I save egress type to the clipboard
    When I execute on the pod:
      | curl           |
      | --head         |
      | www.google.com |
    Then the step should succeed
    And the output should match:
      | HTTP/1.1 20\d |
    Given I obtain test data file "networking/<%= cb.cb_egress_directory %>/limit_policy.json"
    When I run the :create admin command with:
      | f | limit_policy.json |
      | n | <%= project.name %> |
    Then the step should succeed
    When I use the "<%= project.name %>" project
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.google.com |
    Then the step should fail
    When I run the :delete admin command with:
      | object_type       | <%= cb.cb_egress_type %> |
      | object_name_or_id | --all                    |
      | n                 | <%= project.name %>      |
    Then the step should succeed
    When I use the "<%= project.name %>" project
    When I execute on the pod:
      | curl           |
      | --head         |
      | www.google.com |
    Then the step should succeed
    And the output should match:
      | HTTP/1.1 20\d |

  # @author weliang@redhat.com
  # @case_id OCP-13502
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-13502 Apply different egress network policy in different projects
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
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-13507 The rules of egress network policy are added in openflow
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
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-13509 Egress network policy use dnsname with multiple ipv4 addresses
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
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-15005 Service with a DNS name can not by pass Egressnetworkpolicy with that DNS name
    Given the env is using multitenant or networkpolicy network
    Given I have a project
    Given I have a pod-for-ping in the project
    And evaluation of `project.name` is stored in the :proj1 clipboard

    # Create egress policy to deny www.chsi.com.cn
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
      | yahoo.com | www.chsi.com.cn |
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
      | curl | --head | www.chsi.com.cn |
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

    # Create egress policy to allow www.chsi.com.cn
    When I obtain test data file "networking/egress-ingress/dns-egresspolicy2.json"
    And I replace lines in "dns-egresspolicy2.json":
      | 98.138.0.0/16 | 0.0.0.0/0 |
    And I run the :create admin command with:
      | f | dns-egresspolicy2.json |
      | n | <%= cb.proj1 %> |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | --head | www.chsi.com.cn |
    Then the step should succeed

  # @author weliang@redhat.com
  # @case_id OCP-15017
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-15017 Add nodes local IP address to OVS rules for egressnetworkpolicy
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
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @heterogeneous @arm64 @amd64
  Scenario: OCP-13506 Update different dnsname in same egress network policy
    Given I have a project
    Given I have a pod-for-ping in the project

    # Create egressnetworkpolicy to deny www.chsi.com.cn
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy4.json"
    When I run oc create over "dns-egresspolicy4.json" replacing paths:
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.chsi.com.cn |
    Then the step should succeed

    # Access to www.chsi.com.cn fail
    When I execute on the pod:
      | curl |  -I | --connect-timeout | 5 | www.chsi.com.cn |
    Then the step should fail
    And admin ensures "policy-test" egress_network_policy is deleted

    # Create egressnetworkpolicy to deny another domain name yahoo.com 
    Given I obtain test data file "networking/egress-ingress/dns-egresspolicy4.json"
    When I run oc create over "dns-egresspolicy4.json" replacing paths:
      | ["spec"]["egress"][0]["to"]["dnsName"] | yahoo.com | 
    Then the step should succeed

    When I execute on the pod:
      | curl |  -I | --connect-timeout | 5 | yahoo.com | 
    Then the step should fail
    When I execute on the pod:
      | curl | --head | www.chsi.com.cn |
    Then the step should succeed

  # @author huirwang@redhat.com
  # @case_id OCP-19615
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-19615 Iptables should be updated with correct endpoints when egress DNS policy was used
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And 1 pod becomes ready with labels:
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

  # @author huirwang@redhat.com
  # @case_id OCP-33530
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-33530 EgressFirewall allows traffic to destination ports
    Given I have a project
    Given I have a pod-for-ping in the project

    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    And evaluation of `BushSlicer::Common::Net.dns_lookup("www.google.com")` is stored in the :google_ip clipboard
    And evaluation of `IPAddr.new("<%= cb.google_ip %>/24")` is stored in the :google_base_network clipboard
    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy1.yaml"
    When I run oc create as admin over "egressfirewall-policy1.yaml" replacing paths:
      | ["spec"]["egress"][0]["to"]["cidrSelector"] | <%= cb.yahoo_ip %>/32            |
      | ["spec"]["egress"][1]["to"]["cidrSelector"] | <%= cb.google_base_network %>/24 |
      | ["metadata"]["namespace"]                   | <%= project.name %>              |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | <%= cb.yahoo_ip %>:80 |
    Then the step should succeed
    When I execute on the pod:
      | curl | -k | --connect-timeout | 5 | --head | https://<%= cb.yahoo_ip %>:443 |
    Then the step should succeed
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | <%= cb.google_ip %>:80 |
    Then the step should succeed
    When I execute on the pod:
      | curl | -k | --connect-timeout | 5 | --head | https://<%= cb.google_ip %>:443 |
    Then the step should fail
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should fail

  # @author huirwang@redhat.com
  # @case_id OCP-33531
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-33531 EgressFirewall rules take effect in order
    Given I have a project
    Given I have a pod-for-ping in the project

    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy2.yaml"
    When I run oc create as admin over "egressfirewall-policy2.yaml" replacing paths:
      | ["spec"]["egress"][1]["to"]["cidrSelector"] | <%= cb.yahoo_ip %>/32 |
      | ["metadata"]["namespace"]                   | <%= project.name %>   |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | <%= cb.yahoo_ip %>:80 |
    Then the step should fail

  # @author huirwang@redhat.com
  # @case_id OCP-33539
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-33539 EgressFirewall policy should not take effect for traffic between pods and pods to service
    Given I have a project
    # Create EgressFirewall policy to deny all outbound traffic
    When I obtain test data file "networking/ovn-egressfirewall/limit_policy.json"
    And I run the :create admin command with:
      | f | limit_policy.json   |
      | n | <%= project.name %> |

    # Create svc/pods
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `service("test-service").url` is stored in the :svc_url clipboard
    And evaluation of `pod(0).ip_url` is stored in the :pod_ip clipboard

    #The connection between pods and pods to svc should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | -k | <%= cb.svc_url %> |
    Then the output should contain:
      | Hello OpenShift |
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 5 | <%= cb.pod_ip %>:8080 |
    Then the output should contain:
      | Hello OpenShift |


  # @author huirwang@redhat.com
  # @case_id OCP-33565
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-33565 EgressFirewall policy take effect for multiple port
    Given I have a project
    Given I have a pod-for-ping in the project

    And evaluation of `BushSlicer::Common::Net.dns_lookup("yahoo.com")` is stored in the :yahoo_ip clipboard
    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy3.yaml"
    When I run oc create as admin over "egressfirewall-policy3.yaml" replacing paths:
      | ["spec"]["egress"][0]["to"]["cidrSelector"] | <%= cb.yahoo_ip %>/32 |
      | ["metadata"]["namespace"]                   | <%= project.name %>   |
    Then the step should succeed

    # Check curl from pod
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | <%= cb.yahoo_ip %>:80 |
    Then the step should succeed
    When I execute on the pod:
      | curl | -k | --connect-timeout | 5 | --head | https://<%= cb.yahoo_ip %>:443 |
    Then the step should succeed
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should fail

  # @author huirwang@redhat.com
  # @case_id OCP-35341
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-openshiftsdn @network-networkpolicy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-35341 EgressNetworkPolicy maxItems is 1000
    Given I have a project
    Given I obtain test data file "networking/egressnetworkpolicy/egressnetworkpolicy_1000.yaml"
    When I run the :create admin command with:
      | f | egressnetworkpolicy_1000.yaml |
      | n | <%= project.name %>           |
    Then the step should succeed
    And the output should contain:
      | egressnetworkpolicy.network.openshift.io/default created |
    And admin ensures "default" egress_network_policy is deleted
    Given I obtain test data file "networking/egressnetworkpolicy/egressnetworkpolicy_1001.yaml"
    When I run the :create admin command with:
      | f | egressnetworkpolicy_1001.yaml |
      | n | <%= project.name %>           |
    Then the step should fail
    And the output should match:
      | spec.egress.*have at most 1000 items |

  # @author huirwang@redhat.com
  # @case_id OCP-37491
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-37491 EgressFirewall allows traffic to destination dnsName
    Given I have a project
    Given I have a pod-for-ping in the project

    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy4.yaml"
    When I run oc create as admin over "egressfirewall-policy4.yaml" replacing paths:
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.chsi.com.cn       |
      | ["metadata"]["namespace"]              | <%= project.name %>   |

    # Check curl from pod
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should succeed
    When I execute on the pod:
      | curl | -k | --connect-timeout | 5 | --head | https://yahoo.com:443 |
    Then the step should fail
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | http://yahoo.com:80 |
    Then the step should succeed
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | google.com |
    Then the step should fail
    """

  # @author huirwang@redhat.com
  # @case_id OCP-37495
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-37495 EgressFirewall denys traffic to destination dnsName
    Given I have a project

    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy4.yaml"
    And I run oc create as admin over "egressfirewall-policy4.yaml" replacing paths:
      | ["spec"]["egress"][0]["type"]          | Deny                 |
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.chsi.com.cn      | 
      | ["spec"]["egress"][1]["type"]          | Deny                 |
      | ["spec"]["egress"][2]["type"]          | Allow                |
      | ["metadata"]["namespace"]              | <%= project.name %>  |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    # Check curl from pod
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should fail
    When I execute on the pod:
      | curl | -k | --connect-timeout | 5 | --head | https://yahoo.com:443 |
    Then the step should succeed
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | http://yahoo.com:80 |
    Then the step should fail
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | google.com |
    Then the step should succeed

  # @author huirwang@redhat.com
  # @case_id OCP-37496
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-37496 Edit EgressFirewall should take effect
    Given I have a project
    Given I have a pod-for-ping in the project

    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy4.yaml"
    And I run oc create as admin over "egressfirewall-policy4.yaml" replacing paths:
      | ["spec"]["egress"][0]["type"]          | Deny                |
      | ["spec"]["egress"][0]["to"]["dnsName"] | www.chsi.com.cn     |
      | ["metadata"]["namespace"]              | <%= project.name %> |
    Then the step should succeed

    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should fail

    #Edit the egressfirewall rule
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    And as admin I successfully merge patch resource "egressfirewall.k8s.ovn.org/default" with:
      |{"spec":{"egress":[{"type":"Allow","to":{"dnsName":"www.chsi.com.cn"}}]}}|

    Given I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | --connect-timeout | 10 | --head | www.chsi.com.cn |
    Then the step should succeed
    """

  # @author huirwang@redhat.com
  # @case_id OCP-41179
  @admin
  @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-41179 bug1947917 Egress Firewall should reliably apply firewall rules
    Given I have a project
    Given I have a pod-for-ping in the project

    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy5.yaml"
    And I run oc create as admin over "egressfirewall-policy5.yaml" replacing paths:
      | ["metadata"]["namespace"]    | <%= project.name %> |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource      | egressfirewall                 |
      | resource_name | default                        |
      | o             | jsonpath={.status}             |
      | n             | <%= project.name %>            |
    Then the step should succeed
    And the output should contain:
      | EgressFirewall Rules applied |
    """

    #Check the last dns name in yaml file should be allowed
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.amihealthy.com |
    Then the step should succeed

    # Check another dnsname not in the yaml file should be blocked.
    When I execute on the pod:
      | curl | --connect-timeout | 5 | --head | www.chsi.com.cn |
    Then the step should fail


  # @author jechen@redhat.com
  # @case_id OCP-44940
  @admin
  @4.11 @4.10 @4.9    
  @network-ovnkubernetes @network-openshiftsdn	
  @singlenode
  @proxy @noproxy @disconnected @connected
  Scenario: OCP-44940 bug2000057 No segmentation error occurs in ovnkube-master after egressfirewall resource that references a DNS name is deleted
    Given the env is using "OVNKubernetes" networkType
    And I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
		
    When I obtain test data file "networking/ovn-egressfirewall/egressfirewall-policy4.yaml"
    And I run oc create as admin over "egressfirewall-policy4.yaml" replacing paths:
      | ["metadata"]["namespace"]  | <%= project.name %>   |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource      | egressfirewall                 |
      | resource_name | default                        |
      | o             | jsonpath={.status}             |
      | n             | <%= project.name %>            |
    Then the step should succeed
    And the output should contain:
      | EgressFirewall Rules applied |
    """

    When I run the :delete admin command with:
      | object_type       | egressfirewall           |
      | object_name_or_id | default                  |
      | n                 | <%= project.name %>      |
    Then the step should succeed
    
    Given I switch to cluster admin pseudo user
    Given admin uses the "openshift-ovn-kubernetes" project
    Given I store the leader node name from the "ovn-kubernetes-master" configmap to the :leadernode clipboard
    When I run the :get admin command with:
      | resource      | pod                                 |     
      | l             | app=ovnkube-master                  |
      | fieldSelector | spec.nodeName=<%= cb.leadernode %>  |
      | o             | jsonpath={.items[*].metadata.name}  |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :ovnkube_master_podname clipboard

    When I run the :logs client command with:
      | resource_name | <%= cb.ovnkube_master_podname %> |
      | c             | ovnkube-master                   |
      | since         | 30s                              |
    Then the step should succeed
    And the output should not contain "SIGSEGV: segmentation violation"
