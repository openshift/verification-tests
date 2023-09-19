Feature: Testing haproxy router

  # @author hongli@redhat.com
  # @case_id OCP-11903
  @smoke
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-11903:NetworkEdge haproxy cookies based sticky session for unsecure routes
    #create route and service which has two endpoints
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    When I run oc create over "web-server-1.yaml" replacing paths:
      | ["metadata"]["name"] | web-server-2 |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    Given I have a test-client-pod in the project
    #access the route without cookies
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -c |
      | /data/cookies-11903 |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-2"
    """
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-1"
    """
    #access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -b |
      | /data/cookies-11903 |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-2"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11130
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-11130:NetworkEdge haproxy cookies based sticky session for edge termination routes
    #create route and service which has two endpoints
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    When I run oc create over "web-server-1.yaml" replacing paths:
      | ["metadata"]["name"] | web-server-2 |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | route-edge       |
      | service | service-unsecure |
    Then the step should succeed

    Given I have a test-client-pod in the project
    # access the route without cookies
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /data/cookies-11130 |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-1"
    """
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-2"
    """
    # access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -b |
      | /data/cookies-11130 |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-1"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11619
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-11619:NetworkEdge Limit the number of TCP connection per IP in specified time period
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And the pod named "web-server-1" becomes ready
    Given I obtain test data file "routing/service_secure.yaml"
    When I run the :create client command with:
      | f | service_secure.yaml |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name    | route-pass     |
      | service | service-secure |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain 20 times:
      | Hello-OpenShift |
    And the output should not contain "(35)"

    When I run the :annotate client command with:
      | resource | route |
      | resourcename | route-pass |
      | keyval | haproxy.router.openshift.io/rate-limit-connections=true |
      | keyval | haproxy.router.openshift.io/rate-limit-connections.rate-tcp=3 |
    Then the step should succeed

    Given 10 seconds have passed
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain:
      | Hello-OpenShift |
      | (35) |

    Given 6 seconds have passed
    When I execute on the pod:
      | bash | -c | for i in {1..20} ; do curl -ksS https://<%= route("route-pass", service("route-pass")).dns(by: user) %>/ ; done |
    Then the output should contain:
      | Hello-OpenShift |
      | (35) |

  # @author hongli@redhat.com
  # @case_id OCP-15044
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-15044:NetworkEdge The backend health check interval of unsecure route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run oc create over "web-server-rc.yaml" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard

    # create unsecure route
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                   |
      | resourcename | service-unsecure                                        |
      | overwrite    | true                                                    |
      | keyval       | router.openshift.io/haproxy.health.check.interval=200ms |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 200ms |
    """

  # @author hongli@redhat.com
  # @case_id OCP-15049
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-15049:NetworkEdge The backend health check interval of edge route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run oc create over "web-server-rc.yaml" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard

    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                   |
      | resourcename | edge-route                                              |
      | overwrite    | true                                                    |
      | keyval       | router.openshift.io/haproxy.health.check.interval=300ms |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 300ms |
    """

  # @author bmeng@redhat.com
  # @case_id OCP-10043
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-10043:NetworkEdge Set balance leastconn for passthrough routes
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    Given I have a project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run the :create client command with:
      | f | web-server-rc.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=web-server-rc |

    When I run the :create_route_passthrough client command with:
      | name    | route-pass     |
      | service | service-secure |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                         |
      | resourcename | route-pass                                    |
      | keyval       | haproxy.router.openshift.io/balance=leastconn |
      | overwrite    | true                                          |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | backend be_tcp:<%= cb.proj_name %>:route-pass | /var/lib/haproxy/conf/haproxy.config | -A 5 |
    Then the step should succeed
    And the output should contain:
      | balance leastconn |
    """

  # @author yadu@redhat.com
  # @case_id OCP-11679
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-11679:NetworkEdge Disable haproxy hash based sticky session for unsecure routes
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    When I run oc create over "web-server-1.yaml" replacing paths:
      | ["metadata"]["name"] | web-server-2 |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                            |
      | resourcename | service-unsecure                                 |
      | overwrite    | true                                             |
      | keyval       | haproxy.router.openshift.io/disable_cookies=true |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -c |
      | /data/cookies-11679 |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    When I execute on the pod:
      | bash | -c | for i in {1..10} ; do curl -sS  http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ -b /data/cookies-11679 ; done |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift web-server-1 |
      | Hello-OpenShift web-server-2 |

  # @author hongli@redhat.com
  # @case_id OCP-15872
  @smoke
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-15872:NetworkEdge can set cookie name for unsecure routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    When I run oc create over "web-server-1.yaml" replacing paths:
      | ["metadata"]["name"] | web-server-2 |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                             |
      | resourcename | service-unsecure                                  |
      | overwrite    | true                                              |
      | keyval       | router.openshift.io/cookie_name=unsecure-cookie_1 |
    Then the step should succeed

    Given I wait up to 30 seconds for the steps to pass:
    """
    When I open web server via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift web-server-2"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "unsecure-cookie_1"}
    """

    # access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I open web server via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift web-server-2"
    """

  # @author hongli@redhat.com
  # @case_id OCP-15873
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @hypershift-hosted
  @critical
  Scenario: OCP-15873:NetworkEdge can set cookie name for edge routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    When I run oc create over "web-server-1.yaml" replacing paths:
      | ["metadata"]["name"] | web-server-2 |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                         |
      | resourcename | edge-route                                    |
      | overwrite    | true                                          |
      | keyval       | router.openshift.io/cookie_name=2-edge_cookie |
    Then the step should succeed

    When I use the "service-unsecure" service
    And I wait up to 30 seconds for the steps to pass:
    """
    When I open secure web server via the "edge-route" route
    Then the output should contain "Hello-OpenShift web-server-1"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "2-edge_cookie"}
    """

    # access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I open secure web server via the "edge-route" route
    Then the output should contain "Hello-OpenShift web-server-1"
    """
