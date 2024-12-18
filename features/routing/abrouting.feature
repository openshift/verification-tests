Feature: Testing abrouting

  # @author yadu@redhat.com
  # @case_id OCP-12076
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @critical
  @hypershift-hosted
  @network-ovnkubernetes @network-openshiftsdn
  @noproxy
  Scenario: OCP-12076:NetworkEdge Set backends weight for unsecure route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/abrouting/abtest-websrv1.yaml"
    When I run the :create client command with:
      | f | abtest-websrv1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv1 |
    And evaluation of `pod.ip` is stored in the :pod_ip1 clipboard
    Given I obtain test data file "routing/abrouting/abtest-websrv2.yaml"
    When I run the :create client command with:
      | f | abtest-websrv2.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv2 |
    And evaluation of `pod.ip` is stored in the :pod_ip2 clipboard

    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                          |
      | resourcename | service-unsecure                               |
      | overwrite    | true                                           |
      | keyval       | haproxy.router.openshift.io/balance=roundrobin |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | service   | service-unsecure=20   |
      | service   | service-unsecure-2=80 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
    Then the step should succeed
    Then the output should contain 1 times:
      | (20%) |
      | (80%) |

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip1 %> | /var/lib/haproxy/conf/haproxy.config | -C 1 |
    Then the output should match:
      | <%= cb.pod_ip1 %>.* weight 64  |
      | <%= cb.pod_ip2 %>.* weight 256 |
    """

    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | adjust    | true                  |
      | service   | service-unsecure=-10% |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
    Then the step should succeed
    Then the output should contain 1 times:
      | (10%) |
      | (90%) |

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip1 %> | /var/lib/haproxy/conf/haproxy.config | -C 1 |
    Then the output should match:
      | <%= cb.pod_ip1 %>.* weight 28  |
      | <%= cb.pod_ip2 %>.* weight 256 |
    """


  # @author yadu@redhat.com
  # @case_id OCP-11970
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @noproxy @connected
  @critical
  @hypershift-hosted
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: OCP-11970:NetworkEdge Set backends weight for reencrypt route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/abrouting/abtest-websrv1.yaml"
    When I run the :create client command with:
      | f | abtest-websrv1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv1 |
    And evaluation of `pod.ip` is stored in the :pod_ip1 clipboard
    Given I obtain test data file "routing/abrouting/abtest-websrv2.yaml"
    When I run the :create client command with:
      | f | abtest-websrv2.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv2 |
    And evaluation of `pod.ip` is stored in the :pod_ip2 clipboard

    Given I obtain test data file "routing/example_wildcard.pem"
    Given I obtain test data file "routing/example_wildcard.key"
    Given I obtain test data file "routing/reencrypt/route_reencrypt.ca"
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | route-reencrypt                           |
      | hostname   | <%= rand_str(5, :dns) %>-reen.example.com |
      | service    | service-secure                            |
      | cert       | example_wildcard.pem                      |
      | key        | example_wildcard.key                      |
      | cacert     | route_reencrypt.ca                        |
      | destcacert | route_reencrypt_dest.ca                   |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                          |
      | resourcename | route-reencrypt                                |
      | overwrite    | true                                           |
      | keyval       | haproxy.router.openshift.io/balance=roundrobin |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-reencrypt     |
      | service   | service-secure=3    |
      | service   | service-secure-2=7  |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-reencrypt |
    Then the step should succeed
    Then the output should contain 1 times:
      | (30%) |
      | (70%) |

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip1 %> | /var/lib/haproxy/conf/haproxy.config | -C 1 |
    Then the output should match:
      | <%= cb.pod_ip1 %>.* weight 109 |
      | <%= cb.pod_ip2 %>.* weight 256 |
    """

    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | route-reencrypt        |
      | adjust    | true                   |
      | service   | service-secure=-20%  |
    When I run the :set_backends client command with:
      | routename | route-reencrypt |
    Then the step should succeed
    Then the output should contain 1 times:
      | (10%) |
      | (90%) |

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip1 %> | /var/lib/haproxy/conf/haproxy.config | -C 1 |
    Then the output should match:
      | <%= cb.pod_ip1 %>.* weight 28  |
      | <%= cb.pod_ip2 %>.* weight 256 |
    """

  # @author yadu@redhat.com
  # @case_id OCP-13519
  @admin
  @upgrade-sanity
  @4.7 @4.6
  @singlenode
  @noproxy @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @critical
  Scenario: OCP-13519:NetworkEdge The edge route with multiple service will set load balance policy to RoundRobin by default
    #Create pod/service/route
    Given I have a project
    Given I obtain test data file "routing/abrouting/abtest-websrv1.yaml"
    When I run the :create client command with:
      | f | abtest-websrv1.yaml |
    Then the step should succeed
    Given I obtain test data file "routing/abrouting/abtest-websrv2.yaml"
    When I run the :create client command with:
      | f | abtest-websrv2.yaml |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge1            |
      | service | service-unsecure |
    Then the step should succeed
    #Check the default load blance policy
    Given I switch to cluster admin pseudo user
    And I use the router project
    And all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """
    #Add multiple services to route
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=1   |
      | service   | service-unsecure-2=9 |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "roundrobin"
    """
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=0   |
      | service   | service-unsecure-2=1 |
    Then the step should succeed
    #Set one of the service weight to 0
    Given I switch to cluster admin pseudo user
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=0   |
      | service   | service-unsecure-2=0 |
    Then the step should succeed
    #Set all the service weight to 0
    Given I switch to cluster admin pseudo user
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """

  # @author yadu@redhat.com
  # @case_id OCP-15910
  @admin
  @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-15910:NetworkEdge Each endpoint gets weight/numberOfEndpoints portion of the requests - unsecure route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    # Create pods and services
    Given I obtain test data file "routing/abrouting/abtest-websrv1.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv2.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv3.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv4.yaml"
    When I run the :create client command with:
      | f | abtest-websrv1.yaml |
      | f | abtest-websrv2.yaml |
      | f | abtest-websrv3.yaml |
      | f | abtest-websrv4.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv1 |
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard
    # Create route and set route backends
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | service   | service-unsecure=20   |
      | service   | service-unsecure-2=10 |
      | service   | service-unsecure-3=30 |
      | service   | service-unsecure-4=40 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure  |
    Then the step should succeed
    Then the output should contain:
      | 20% |
      | 10% |
      | 30% |
      | 40% |
    # Scale pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv1         |
      | replicas | 2                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv2         |
      | replicas | 4                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv3         |
      | replicas | 3                      |
    Then the step should succeed
    And all pods in the project are ready

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config | -C 9 |
    Then the output should match:
      | :service-unsecure:.* weight 64    |
      | :service-unsecure:.* weight 64    |
      | :service-unsecure-2:.* weight 16  |
      | :service-unsecure-2:.* weight 16  |
      | :service-unsecure-2:.* weight 16  |
      | :service-unsecure-2:.* weight 16  |
      | :service-unsecure-3:.* weight 64  |
      | :service-unsecure-3:.* weight 64  |
      | :service-unsecure-3:.* weight 64  |
      | :service-unsecure-4:.* weight 256 |
    """

  # @author yadu@redhat.com
  # @case_id OCP-15994
  @admin
  @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-15994:NetworkEdge Each endpoint gets weight/numberOfEndpoints portion of the requests - passthrough route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    # Create pods and services
    Given I obtain test data file "routing/abrouting/abtest-websrv1.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv2.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv3.yaml"
    Given I obtain test data file "routing/abrouting/abtest-websrv4.yaml"
    When I run the :create client command with:
      | f | abtest-websrv1.yaml |
      | f | abtest-websrv2.yaml |
      | f | abtest-websrv3.yaml |
      | f | abtest-websrv4.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=abtest-websrv1 |
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard
    # Create route and set route backends
    When I run the :create_route_passthrough client command with:
      | name    | route-pass     |
      | service | service-secure |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-pass            |
      | service   | service-secure=20   |
      | service   | service-secure-2=10 |
      | service   | service-secure-3=30 |
      | service   | service-secure-4=40 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-pass            |
    Then the step should succeed
    Then the output should contain:
      | 20% |
      | 10% |
      | 30% |
      | 40% |
    # Scale pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv1         |
      | replicas | 2                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv2         |
      | replicas | 4                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | abtest-websrv3         |
      | replicas | 3                      |
    Then the step should succeed
    And all pods in the project are ready

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config | -C 9 |
    Then the output should match:
      | :service-secure:.* weight 64    |
      | :service-secure:.* weight 64    |
      | :service-secure-2:.* weight 16  |
      | :service-secure-2:.* weight 16  |
      | :service-secure-2:.* weight 16  |
      | :service-secure-2:.* weight 16  |
      | :service-secure-3:.* weight 64  |
      | :service-secure-3:.* weight 64  |
      | :service-secure-3:.* weight 64  |
      | :service-secure-4:.* weight 256 |
    """
