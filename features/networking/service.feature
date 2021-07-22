Feature: Service related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-9604
  @admin
  Scenario: tenants can access their own services
    # create pod and service in project1
    Given the env is using multitenant network
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    Given I use the "test-service" service
    And evaluation of `service.ip` is stored in the :service1_ip clipboard
    Given I wait for the "test-service" service to become ready

    # create pod and service in project2
    Given I switch to the second user
    And I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    Given I use the "test-service" service
    And evaluation of `service.ip` is stored in the :service2_ip clipboard

    # access service in project2
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | -k | <%= cb.service2_ip %>:27017 |
    Then the output should contain:
      | Hello OpenShift |

    # access service in project1
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 4 | <%= cb.service1_ip %>:27017 |
    Then the step should fail
    Then the output should not contain:
      | Hello OpenShift |

  # @author yadu@redhat.com
  # @case_id OCP-15032
  @admin
  Scenario: The openflow list will be cleaned after delete the services
    Given the env is using one of the listed network plugins:
      | subnet      |
      | multitenant |
    Given I have a project
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    Given I use the "service-unsecure" service
    And evaluation of `service.ip` is stored in the :service_ip clipboard
    Given I select a random node's host
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should contain:
      | <%= cb.service_ip %> |
    When I run the :delete client command with:
      | object_type       | svc              |
      | object_name_or_id | service-unsecure |
    Then the step should succeed
    Given I select a random node's host
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should not contain:
      | <%= cb.service_ip %> |

  # @author anusaxen@redhat.com
  # @case_id OCP-23895
  @admin
  Scenario: User cannot access the MCS by creating a LoadBalancer service that points to the MCS
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master_ip clipboard
    Given I select a random node's host
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    And I have a pod-for-ping in the project

    #Creating laodbalancer service that points to MCS IP
    When I run the :create_service_loadbalancer client command with:
      | name | <%= cb.ping_pod.name %>  |
      | tcp  | 22623:8080               |
    Then the step should succeed

    # Editing endpoint to point to master ip
    When I run the :patch client command with:
      | resource      | ep                         				      						   |
      | resource_name | <%= cb.ping_pod.name %>                  		      						   |
      | p             | {"subsets": [{"addresses": [{"ip": "<%= cb.master_ip %>"}],"ports": [{"port": 22623,"protocol": "TCP"}]}]} |
      | type          | merge                                			      						   |
    Then the step should fail
    And the output should contain "endpoints "<%= cb.ping_pod.name %>" is forbidden: endpoint port TCP:22623 is not allowed"

  # @author huirwang@redhat.com
  # @case_id OCP-21814
  @admin
  Scenario: The headless service can publish the pods even if they are not ready
    Given I have a project
    Given I obtain test data file "networking/headless_notreadypod.json"
    When I run the :create client command with:
      | f | headless_notreadypod.json |
    Then the step should succeed
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | pod                     |
    Then the step should succeed
    And the output should match 2 times:
      | (Err)?ImagePull(BackOff)?\\s+0 |
    """

    When I run the :get client command with:
      | resource      | ep          |
      | resource_name | test-service |
    Then the step should succeed
    And the output should contain:
	    | 8080 |

  # @author weliang@redhat.com
  # @case_id OCP-24668
  Scenario: externalIP defined in service but no spec.externalIP defined
    Given I have a project
    # Create a service with a externalIP
    Given I obtain test data file "networking/externalip_service1.json"
    When I run the :create client command with:
      | f | externalip_service1.json |
    Then the step should fail

  # @author weliang@redhat.com
  # @case_id OCP-24669
  @admin
  @destructive
  Scenario: externalIP defined in service with set ExternalIP in allowedCIDRs
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
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

  # @author weliang@redhat.com
  # @case_id OCP-24692
  @admin
  @destructive
  Scenario: A rejectedCIDRs inside an allowedCIDRs
    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["22.2.2.0/24"],"rejectedCIDRs":["22.2.2.0/25"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy": {"allowedCIDRs": null, "rejectedCIDRs": null}}}}  |
    """

    # Create a svc with externalIP/22.2.2.10 which is in 22.2.2.0/25
    Given I have a project
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.10 |
    Then the step should fail
    """

    # Create a svc with externalIP/22.2.2.130 which is not in 22.2.2.0/25
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.130 |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready

    # Curl externalIP:portnumber on new pod
    When I execute on the pod:
      | /usr/bin/curl | -k | 22.2.2.130:27017 |
    Then the output should contain:
      | Hello OpenShift! |

  # @author weliang@redhat.com
  # @case_id OCP-24670
  @admin
  @destructive
  Scenario: externalIP defined in service with set ExternalIP in rejectedCIDRs
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    Given I store the schedulable nodes in the :nodes clipboard
    And the Internal IP of node "<%= cb.nodes[0].name %>" is stored in the :hostip clipboard

    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"rejectedCIDRs":["<%= cb.hostip %>/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"rejectedCIDRs": null}}}} |
    """

    # Create a svc with externalIP
    Given I switch to the first user
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %> |
    Then the step should fail
    """

  # @author weliang@redhat.com
  # @case_id OCP-24739
  @admin
  @destructive
  Scenario: An allowedCIDRs inside an rejectedCIDRs
    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["22.2.2.0/25"],"rejectedCIDRs":["22.2.2.0/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy": {"allowedCIDRs": null, "rejectedCIDRs": null}}}} |
    """

    # Create a svc with externalIP/22.2.2.10 which is in rejectedCIDRs
    Given I have a project
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.10 |
    Then the step should fail
    """

    # Create a svc with externalIP/22.2.2.130 which is in rejectedCIDRs
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.130 |
    Then the step should fail
    """

  # @author weliang@redhat.com
  # @case_id OCP-24691
  @admin
  @destructive
  Scenario: Defined Multiple allowedCIDRs
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    Given I store the schedulable nodes in the :nodes clipboard
    And the Internal IP of node "<%= cb.nodes[0].name %>" is stored in the :host1ip clipboard
    And the Internal IP of node "<%= cb.nodes[1].name %>" is stored in the :host2ip clipboard

    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["<%= cb.host1ip %>/24","<%= cb.host2ip %>/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":null }}}} |
    """

    # Create a svc with externalIP
    Given I switch to the first user
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.host1ip %> |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready

    # Curl externalIP:portnumber from pod
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.host1ip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

    # Delete created pod and svc
    When I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed

    # Create a svc with second externalIP
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.host2ip %> |
    Then the step should succeed
    """

    # Create a pod
   Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready

    # Curl externalIP:portnumber on new pod
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.host2ip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

  # @author anusaxen@redhat.com
  # @case_id OCP-26035
  @admin
  Scenario: Idling/Unidling services on sdn/OVN
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    Given I use the "test-service" service
    And evaluation of `service.url(user: user)` is stored in the :service_url clipboard
    # Checking idling unidling manually to make sure it works fine
    When I run the :idle client command with:
      | svc_name | test-service |
    Then the step should succeed
    And the output should contain:
      | The service "<%= project.name %>/test-service" has been marked as idled |
    Given I have a pod-for-ping in the project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 30 | <%= cb.service_url %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    """

  # @author huirwang@redhat.com
  # @case_id OCP-11645
  Scenario: Create loadbalancer service
    Given I have a project
    Given I obtain test data file "networking/ping_for_pod_containerPort.json"
    When I run the :create client command with:
      | f | ping_for_pod_containerPort.json |
    Then the step should succeed

    # Create loadbalancer service
    When I run the :create_service_loadbalancer client command with:
      | name | hello-pod |
      | tcp  | 5678:8081 |
    Then the step should succeed

    # Get the external ip of the loadbaclancer service
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | svc                                        |
      | resource_name | hello-pod                                  |
      | template      | {{(index .status.loadBalancer.ingress 0)}} |
    Then the step should succeed
    """
    And evaluation of `@result[:response].match(/:(.*)]/)[1]` is stored in the :service_hostname clipboard

    # check the external:ip of loadbalancer can be accessed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | name=test-pods |
    And I wait up to 90 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | --connect-timeout | 2 | <%= cb.service_hostname %>:5678 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    """

  # @author anusaxen@redhat.com
  # @case_id OCP-24694
  @admin
  @destructive
  Scenario: Taint node with too small MTU value
    Given the default interface on nodes is stored in the :default_interface clipboard
    And the node's MTU value is stored in the :mtu_actual clipboard
    And the node's active nmcli connection is stored in the :nmcli_active_con_uuid clipboard
    And evaluation of `node.name` is stored in the :subject_node clipboard
    And I run commands on the host:
      | nmcli con modify  "<%= cb.nmcli_active_con_uuid %>"  ethernet.mtu  1300  |
      | nmcli dev reapply <%= cb.default_interface %> |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given I use the "<%= cb.subject_node %>" node
    And I run commands on the host:
      | nmcli con modify "<%= cb.nmcli_active_con_uuid %>" ethernet.mtu <%= cb.mtu_actual %> |
      | nmcli dev reapply  <%= cb.default_interface %> |
    Then the step should succeed
    """
    #This def will also store network project name in network_project_name variable
    Given I store "<%= cb.subject_node %>" node's corresponding default networkType pod name in the :subject_node_network_pod clipboard
    And admin ensures "<%= cb.subject_node_network_pod %>" pod is deleted from the "<%= cb.network_project_name %>" project
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.subject_node %> |
    Then the step should succeed
    And the output should contain "mtu-too-small"
    """
    #Reset the MTU using nmcli
    Given I use the "<%= cb.subject_node %>" node
    And I run commands on the host:
      | nmcli con modify "<%= cb.nmcli_active_con_uuid %>" ethernet.mtu <%= cb.mtu_actual %> |
      | nmcli dev reapply  <%= cb.default_interface %> |
    Then the step should succeed
    And the node's MTU value is stored in the :mtu_actual_redeployed clipboard
    And the expression should be true> cb.mtu_actual == cb.mtu_actual_redeployed
    #The node should get un-taint post this step in few seconds
    And I run commands on the host:
      | pkill openshift-sdn |
    Then the step should succeed
    #Check if node has removed the taint
    Given I wait up to 30 seconds for the steps to pass:
    """
    Given I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.subject_node %> |
    Then the step should succeed
    And the output should not contain "mtu-too-small"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-33848
  @admin
  @destructive
  Scenario: User can expand the nodePort range by patch the serviceNodePortRange in network
    Given I store the workers in the :workers clipboard
    And the Internal IP of node "<%= cb.workers[0].name %>" is stored in the :worker0_ip clipboard
    Given I have a project
    And evaluation of `rand(32676..33000)` is stored in the :port clipboard
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"serviceNodePortRange": "30000-33000"}} |
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    When I obtain test data file "networking/nodeport_test_service.yaml"
    And I wait up to 600 seconds for the steps to pass:
    """
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"] | <%= cb.port %> |
    Then the step should succeed
    """
    Given the pod named "hello-pod" becomes ready
    Given I use the "<%= cb.workers[0].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.worker0_ip %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.worker0_ip %>:<%= cb.port %> |
    Then the step should fail

  # @author zzhao@redhat.com
  # @case_id OCP-33850
  @admin
  @destructive
  Scenario: User cannot decrease the nodePort range in post action
    When I run the :patch admin command with:
      | resource      | networks.config.openshift.io                     |
      | resource_name | cluster                                          |
      | p             | {"spec":{"serviceNodePortRange": "30000-31000"}} |
      | type          | merge                                            |
    Then the step should fail
    And the output should contain "does not completely cover the previous range"

  # @author zzhao@redhat.com
  # @case_id OCP-10216
  @admin
  Scenario: The iptables rules for the service should be DNAT or REDIRECT to node after being idled
    Given I have a project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And I wait until number of replicas match "1" for replicationController "test-rc"
    Given I use the "test-service" service
    And evaluation of `service.ip` is stored in the :service_ip clipboard

    Given I have a pod-for-ping in the project
    And evaluation of `pod('hello-pod').node_ip` is stored in the :hostip clipboard
    Given I use the "<%= pod.node_name %>" node
    When I run the :idle client command with:
      | svc_name | test-service |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "test-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | test-service.*none |
    When I run commands on the host:
      | iptables -S -t nat \| grep <%= cb.proj_name %>/test-service |
    Then the step should succeed
    And the output should match:
      | KUBE-PORTALS-CONTAINER -d <%= cb.service_ip %>/32 -p tcp .* -m tcp --dport 27017 -j (DNAT --to-destination <%= cb.hostip %>:\d+\|REDIRECT --to-ports \d+) |
      | KUBE-PORTALS-HOST -d <%= cb.service_ip %>/32 -p tcp .* -m tcp --dport 27017 -j DNAT --to-destination <%= cb.hostip %>:\d+ |

    Then I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | --max-time | 60 | <%= cb.service_ip %>:27017 |
    Then the output should contain "Hello OpenShift!"
    """
    Given a pod becomes ready with labels:
      | name=test-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | test-service\s+<%= cb.pod_ip %>:8080 |
    When I run commands on the host:
      | iptables -S -t nat \| grep <%= cb.proj_name %>/test-service |
    Then the step should succeed
    And the output should not contain "REDIRECT"
    And the output should match:
      | KUBE-SEP-.+ -s <%= cb.pod_ip %>/32 .* -j KUBE-MARK-MASQ                                |
      | KUBE-SEP-.+ -p tcp .* -m tcp -j DNAT --to-destination <%= cb.pod_ip %>:8080            |
      | KUBE-SERVICES -d <%= cb.service_ip %>/32 -p tcp .* -m tcp --dport 27017 -j KUBE-SVC-.+ |
      | KUBE-SVC-.+ .* -j KUBE-SEP-.+                                                          |
