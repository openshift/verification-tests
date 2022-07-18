Feature: Service related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-9604
  @admin
  @network-multitenant
  Scenario: OCP-9604:SDN tenants can access their own services
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
    Then the output should not contain:
      | Hello OpenShift |

  # @author yadu@redhat.com
  # @case_id OCP-15032
  @admin
  @inactive
  @network-multitenant
  Scenario: OCP-15032:SDN The openflow list will be cleaned after delete the services
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-23895:SDN User cannot access the MCS by creating a LoadBalancer service that points to the MCS
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21814:SDN The headless service can publish the pods even if they are not ready
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24668:SDN externalIP defined in service but no spec.externalIP defined
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24669:SDN externalIP defined in service with set ExternalIP in allowedCIDRs
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24692:SDN A rejectedCIDRs inside an allowedCIDRs
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24670:SDN externalIP defined in service with set ExternalIP in rejectedCIDRs
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24739:SDN An allowedCIDRs inside an rejectedCIDRs
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24691:SDN Defined Multiple allowedCIDRs
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-26035:SDN Idling/Unidling services on sdn/OVN
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
  @inactive
  Scenario: OCP-11645:SDN Create loadbalancer service
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24694:SDN Taint node with too small MTU value
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-33848:SDN User can expand the nodePort range by patch the serviceNodePortRange in network
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
    Given a pod becomes ready with labels:
      | name=hello-pod |
    Given I use the "<%= cb.workers[0].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.worker0_ip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.worker0_ip %>]:<%= cb.port %> |
    And the output should contain:
      | Connection refused |      

  # @author zzhao@redhat.com
  # @case_id OCP-33850
  @admin
  @destructive
  @proxy @noproxy @disconnected @connected
  @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: OCP-33850:SDN User cannot decrease the nodePort range in post action
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
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-openshiftsdn @network-networkpolicy @network-multitenant
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10216:SDN The iptables rules for the service should be DNAT or REDIRECT to node after being idled
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


  # @author jechen@redhat.com
  # @case_id OCP-43493
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-43493:SDN Update externalIP from oc edit svc
    Given I have a project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    Given I store the schedulable nodes in the :nodes clipboard
 
    # Add externalIP policy to CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
	    | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["1.1.1.0/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs": null}}}} |
    """
 
    # Create a svc with externalIP
    Given I switch to the first user
    And I use the "<%= cb.proj_name %>" project
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | 1.1.1.1 |
    Then the step should succeed
    """
 
    # Create a pod
    Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready
 
    # Curl externalIP:portnumber should pass
    Given I use the "<%= cb.nodes[0].name %>" node
    And I run commands on the host:
      | curl --connect-timeout 5 1.1.1.1:27017 |
    Then the step should succeed
    And the output should contain "Hello OpenShift!"
 
    # change externalIP for the svc
    Given I switch to the first user
    And I use the "<%= cb.proj_name %>" project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :patch client command with:
      | resource      | service                              |
      | resource_name | service-unsecure                     |
      | p             | {"spec":{"externalIPs":["1.1.1.2"]}} |
    Then the step should succeed
    """
 
    # Curl new externalIP:portnumber should pass
    Given I use the "<%= cb.nodes[0].name %>" node
    And I run commands on the host:
      | curl --connect-timeout 5 1.1.1.2:27017 |
    Then the step should succeed
    And the output should contain "Hello OpenShift!"

  # @author zzhao@redhat.com
  # @case_id OCP-47087
  @4.12 @4.11 @4.10
  @admin
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @connected
  @network-ovnkubernetes
  @heterogeneous @arm64 @amd64
  Scenario: OCP-47087:SDN Other node cannot be accessed for nodePort when externalTrafficPolicy is Local
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
    And I store "<%= pod.node_name %>" node's corresponding default networkType pod name in the :ovnkube_node_pod clipboard
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"]  | <%= cb.port %> |
      | ["spec"]["externalTrafficPolicy"] | Local          |
    Then the step should succeed

    Given I use the "<%= cb.masters[1].name %>" node
    #It should work because its external traffic from another node and destination node has a backend pod on it (ETP=local respected)
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %>|
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    #It should NOT work because its external traffic from another node and destination node DOES NOT have a backend pod on it (ETP=local respected)
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master0_ip %>]:<%= cb.port %> |
    And the output should contain:
      | Connection refused |
    #It should work like ETP=cluster because its not external traffic, its within the node (ETP=local shouldn't be respected and its like ETP=cluster behaviour) 
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master1_ip %>]:<%= cb.port %> |
    And the output should contain:
      | Hello OpenShift! |
    
    Given admin ensure "<%= cb.ovnkube_node_pod %>" pod is deleted from the "openshift-ovn-kubernetes" project
    And I wait up to 120 seconds for the steps to pass:
    """
    And OVN is functional on the cluster
    """
    #repeating same flow as above post network pod deletion
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master0_ip %>]:<%= cb.port %> |
    And the output should not contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master1_ip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.proj1 %>" project
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    And the output should not contain:
      | Hello OpenShift! |

  # @author zzhao@redhat.com
  # @case_id OCP-10770
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @admin
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10770:SDN Be able to access the service via the nodeport
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master0_ip clipboard
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
    Then the step should succeed

    Given I use the "<%= cb.masters[1].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.master0_ip %>]:<%= cb.port %> |
    Then the step should succeed 
    And the output should contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.hostip %>]:<%= cb.port %> |
    And the output should contain:
      | Connection refused |      
