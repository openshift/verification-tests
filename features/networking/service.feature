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
    And evaluation of `service.ip(user: user)` is stored in the :service1_ip clipboard
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
    And evaluation of `service.ip(user: user)` is stored in the :service2_ip clipboard

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
    Given I obtain test data file "routing/unsecure/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    Given I use the "service-unsecure" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
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
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %> |
    Then the step should succeed
    """ 
    
    # Create a pod
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
 
    # Curl externalIP:portnumber should pass
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello-OpenShift-1 http-8080 |

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
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.10 |
    Then the step should fail
    """

    # Create a svc with externalIP/22.2.2.130 which is not in 22.2.2.0/25
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.130 |
    Then the step should succeed
    """
 
    # Create a pod
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
 
    # Curl externalIP:portnumber on new pod 
    When I execute on the pod:
      | /usr/bin/curl | -k | 22.2.2.130:27017 |
    Then the output should contain:
      | Hello-OpenShift-1 http-8080 |

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
    And I wait up to 300 seconds for the steps to pass:
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
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 22.2.2.10 |
    Then the step should fail
    """

    # Create a svc with externalIP/22.2.2.130 which is in rejectedCIDRs
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 300 seconds for the steps to pass:
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
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.host1ip %> |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
 
    # Curl externalIP:portnumber from pod 
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.host1ip %>:27017 |
    Then the output should contain:
      | Hello-OpenShift-1 http-8080 |
    
    # Delete created pod and svc
    When I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed

    # Create a svc with second externalIP
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.host2ip %> |
    Then the step should succeed
    """
    
    # Create a pod
    Given I obtain test data file "routing/caddy-docker.json"
    When I run the :create client command with:
      | f | caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
 
    # Curl externalIP:portnumber on new pod 
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.host2ip %>:27017 |
    Then the output should contain:
      | Hello-OpenShift-1 http-8080 |

  # @author anusaxen@redhat.com
  # @case_id OCP-26035
  @admin
  Scenario: Idling/Unidling services on OVN
  Given the env is using "OVNKubernetes" networkType
  And I have a project
    Given I obtain test data file "networking/list_for_pods.json"
  When I run the :create client command with:
    | f | list_for_pods.json |
  Then the step should succeed
  And a pod becomes ready with labels:
    | name=test-pods |
  Given I use the "test-service" service
  And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
  # Checking idling unidling manually to make sure it works fine
  When I run the :idle client command with:
    | svc_name | test-service |
  Then the step should succeed
  And the output should contain:
    | The service "<%= project.name %>/test-service" has been marked as idled |
  Given I have a pod-for-ping in the project
  When I execute on the pod:
    | /usr/bin/curl | --connect-timeout | 30 | <%= cb.service_ip %>:27017 |
  Then the step should succeed
  And the output should contain:
    | Hello OpenShift |

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
      | tcp  | 5678:8080 |
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
    Given 1 pods become ready with labels:
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
    And evaluation of `node.name` is stored in the :subject_node clipboard
    And I run commands on the host:
      | systemctl stop NetworkManager                        |
      | ip link set mtu 1300 dev <%= cb.default_interface %> |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given I use the "<%= cb.subject_node %>" node
    And I run commands on the host:
      | systemctl start NetworkManager |
    Then the step should succeed
    """
    #This def will also store network project name in network_project_name variable
    Given I store "<%= cb.subject_node %>" node's corresponding default networkType pod name in the :subject_node_network_pod clipboard
    And admin ensure "<%= cb.subject_node_network_pod %>" pod is deleted from the "<%= cb.network_project_name %>" project
    When I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.subject_node %> |
    Then the step should succeed
    And the output should contain "mtu-too-small"
    #Starting NetworkManager to roll out original system MTU 
    Given I use the "<%= cb.subject_node %>" node
    And I run commands on the host:
      | systemctl start NetworkManager |
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
