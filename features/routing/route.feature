Feature: Testing route

  # @author hongli@redhat.com
  # @case_id OCP-12122
  @smoke
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-12122:NetworkEdge Alias will be invalid after removing it
    Given I have a project
    Given I obtain test data file "routing/header-test/deployment.yaml"
    When I run the :create client command with:
      | f | deployment.yaml |
    Then the step should succeed
    Given I obtain test data file "routing/header-test/insecure-service.json"
    When I run the :create client command with:
      | f | insecure-service.json |
    Then the step should succeed
    When I expose the "header-test-insecure" service
    Then the step should succeed
    Then I wait for a web server to become available via the "header-test-insecure" route
    When I run the :delete client command with:
      | object_type | route |
      | object_name_or_id | header-test-insecure |
    Then I wait for the resource "route" named "header-test-insecure" to disappear
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "header-test-insecure" route
    Then the step should fail
    """

  # @author hongli@redhat.com
  # @case_id OCP-10660
  @smoke
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-10660:NetworkEdge Service endpoint can be work well if the mapping pod ip is updated
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.name` is stored in the :pod_name clipboard

    When I run the :get client command with:
      | resource | endpoints |
    Then the output should contain:
      | test-service |
      | :8080        |
    Given I get project replicationcontroller as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :rc_name clipboard
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
      | replicas | 0                      |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear
    When I run the :get client command with:
      | resource | endpoints |
    Then the output should contain:
      | test-service |
      | none         |

    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
      | replicas | 1                      |
    And I wait until number of replicas match "1" for replicationController "<%= cb.rc_name %>"
    And a pod becomes ready with labels:
      | name=test-pods |
    When I run the :get client command with:
      | resource | endpoints |
    Then the output should contain:
      | test-service |
      | :8080        |

  # @author hongli@redhat.com
  # @case_id OCP-12652
  @smoke
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-12652:NetworkEdge The later route should be HostAlreadyClaimed when there is a same host exist
    Given I have a project
    Given I obtain test data file "routing/unsecure/route_unsecure.json"
    When I run the :create client command with:
      | f |  route_unsecure.json  |
    Then the step should succeed
    Given I create a new project
    Given I obtain test data file "routing/unsecure/route_unsecure.json"
    When I run the :create client command with:
      | f |  route_unsecure.json  |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | route  |
      | resource_name | route  |
    Then the output should contain "HostAlreadyClaimed"
    """

  # @author hongli@redhat.com
  # @case_id OCP-12562
  @smoke
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-12562:NetworkEdge The path specified in route can work well for edge terminated
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed

    Given I have a test-client-pod in the project
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
      | path    | /test            |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/test/ |
      | -c |
      | /data/cookie-12562 |
      | -k |
    Then the output should contain "Hello-OpenShift-Path-Test"
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
      | -k |
    Then the output should contain "Application is not available"
    When I execute on the pod:
      | cat | /data/cookie-12562 |
    Then the step should succeed
    And the output should not contain "OPENSHIFT"
    And the output should not match "\d+\.\d+\.\d+\.\d+"

    ## add extra steps for BZ #1660598: remove path then re-add the same path
    When I run the :patch client command with:
      | resource      | route                  |
      | resource_name | edge-route             |
      | p             | {"spec": {"path": ""}} |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
      | -k |
    Then the output should contain "Hello-OpenShift"
    """
    When I run the :patch client command with:
      | resource      | route                       |
      | resource_name | edge-route                  |
      | p             | {"spec": {"path": "/test"}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | route |
    Then the step should succeed
    And the output should not contain:
      | HostAlreadyClaimed |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/test/ |
      | -k |
    Then the output should contain "Hello-OpenShift-Path-Test"
    """

  # @author shudili@redhat.com
  # @case_id OCP-12564
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-12564:NetworkEdge The path specified in route can work well for reencrypt terminated
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_secure.yaml"
    When I run the :create client command with:
      | f | service_secure.yaml |
    Then the step should succeed
    Given I have a test-client-pod in the project
    # check reencrypt route
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | route-recrypt           |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
      | path       | /test                   |
    Then the step should succeed
    Then I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/test/ |
      | -k |
    Then the output should contain "Hello-OpenShift-Path-Test"
    """
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/ |
      | -k |
    Then the output should contain "Application is not available"
    """

  # @author yadu@redhat.com
  # @case_id OCP-9651
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-9651:NetworkEdge Config insecureEdgeTerminationPolicy to Redirect for route
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    # Create edge termination route
    When I run the :create_route_edge client command with:
      | name     | myroute |
      | service  | service-unsecure     |
    Then the step should succeed
    # Set insecureEdgeTerminationPolicy to Redirect
    When I run the :patch client command with:
      | resource      | route              |
      | resource_name | myroute            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Redirect"}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | route |
    Then the step should succeed
    And the output should contain:
      | Redirect |
    # Acess the route
    Given I have a test-client-pod in the project
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | ocation: https:// |

  # @author yadu@redhat.com
  # @case_id OCP-9650
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @inactive
  Scenario: OCP-9650:NetworkEdge Config insecureEdgeTerminationPolicy to Allow for route
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name     | myroute          |
      | service  | service-unsecure |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | route   |
      | resource_name | myroute |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Allow"}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | route |
    Then the step should succeed
    And the output should contain:
      | Allow |
    Given I have a test-client-pod in the project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                                                                                          |
      | https://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/                   |
      | -k                                                                                            |
      | -v                                                                                            |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
    And the output should not contain:
      | HTTP/1.1 302 Found |
    """
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                                                                                         |
      | http://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/                   |
      | -v                                                                                           |
      | -c                                                                                           |
      | /data/cookie-9650                                                                            |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
    And the output should not contain:
      | HTTP/1.1 302 Found |
    And I execute on the pod:
      | cat | /data/cookie-9650 |
    Then the step should succeed
    And the output should match:
      | FALSE.*FALSE |
    """

  # @author hongli@redhat.com
  # @case_id OCP-10024
  @smoke
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-10024:NetworkEdge Route could NOT be updated after created
    Given I have a project
    Given I obtain test data file "routing/route_withouthost1.json"
    When I run the :create client command with:
      | f | route_withouthost1.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | route                                   |
      | resource_name | service-unsecure1                       |
      | p             | {"spec":{"host":"www.changeroute.com"}} |
    Then the output should contain:
      | spec.host: Invalid value: "www.changeroute.com": field is immutable |

  # @author zzhao@redhat.com
  # @case_id OCP-11036
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-11036:NetworkEdge Set insecureEdgeTerminationPolicy to Redirect for passthrough route
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_secure.yaml"
    When I run the :create client command with:
      | f | service_secure.yaml |
    Then the step should succeed
    # Create passthrough termination route
    When I run the :create_route_passthrough client command with:
      | name     | myroute |
      | service  | service-secure     |
    Then the step should succeed
    # Set insecureEdgeTerminationPolicy to Redirect
    When I run the :patch client command with:
      | resource      | route              |
      | resource_name | myroute            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Redirect"}}} |
    Then the step should succeed
    # Acess the route
    Given I have a test-client-pod in the project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("myroute", service("service-secure")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | ocation: https:// |
    """
    When I run the :patch client command with:
      | resource      | route              |
      | resource_name | myroute            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Allow"}}} |
    Then the step should fail
    And the output should contain "acceptable values are None, Redirect, or empty"

  # @author zzhao@redhat.com
  # @case_id OCP-13839
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-13839:NetworkEdge Set insecureEdgeTerminationPolicy to Redirect and Allow for reencrypt route
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_secure.yaml"
    When I run the :create client command with:
      | f | service_secure.yaml |
    Then the step should succeed

    #create reencrypt termination route
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | reen                    |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    And I wait up to 60 seconds for a secure web server to become available via the "reen" route
    # Set insecureEdgeTerminationPolicy to Redirect
    When I run the :patch client command with:
      | resource      | route           |
      | resource_name | reen            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Redirect"}}} |
    Then the step should succeed
    # Acess the route
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("reen", service("service-secure")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | ocation: https:// |
    """
    When I run the :patch client command with:
      | resource      | route           |
      | resource_name | reen            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Allow"}}} |
    Then the step should succeed
    # Acess the route
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | http://<%= route("reen", service("service-secure")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-13248
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-13248:NetworkEdge The hostname should be converted to available route when met special character
    Given I have a project
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f  | service_unsecure.yaml |
    Then the step should succeed

    # test those 4 kind of route. When creating route which name have '.', it will be decoded to '-'.
    When I run the :expose client command with:
      | resource      | service          |
      | resource_name | service-unsecure |
      | name          | unsecure.test    |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge.test        |
      | service | service-unsecure |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name    | pass.test        |
      | service | service-unsecure |
    Then the step should succeed
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    And I run the :create_route_reencrypt client command with:
      | name       | reen.test               |
      | service    | service-unsecure        |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I run the :get client command with:
      | resource | route |
    Then the step should succeed
    And the output should contain:
      | unsecure-test- |
      | edge-test-     |
      | pass-test-     |
      | reen-test-     |

  # @author zzhao@redhat.com
  # @case_id OCP-13753
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-13753:NetworkEdge Check the cookie if using secure mode when insecureEdgeTerminationPolicy to Redirect for edge/reencrypt route
    Given I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server |
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    # Create edge termination route
    When I run the :create_route_edge client command with:
      | name     | myroute           |
      | service  | service-unsecure  |
      | insecure_policy | Redirect   |
    Then the step should succeed

    Given I have a test-client-pod in the project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /data/cookie-13753-edge |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | ocation: https:// |
    """
    And I execute on the pod:
      | cat | /data/cookie-13753-edge |
    Then the step should succeed
    And the output should match:
      | FALSE.*TRUE |

    #create reencrypt termination route
    Given I obtain test data file "routing/service_secure.yaml"
    Given I run the :create client command with:
      | f | service_secure.yaml |
    Then the step should succeed
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name            | reen                    |
      | service         | service-secure          |
      | destcacert      | route_reencrypt_dest.ca |
      | insecure_policy | Redirect                |
    Then the step should succeed
    And I wait up to 60 seconds for a secure web server to become available via the "reen" route
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("reen", service("service-secure")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /data/cookie-13753-reen |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | ocation: https:// |
    """
    And I execute on the pod:
      | cat | /data/cookie-13753-reen |
    Then the step should succeed
    And the output should match:
      | FALSE.*TRUE |

  # @author zzhao@redhat.com
  # @case_id OCP-14059
  @admin
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @ppc64le @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-14059:NetworkEdge Use the default destination CA of router if the route does not specify one for reencrypt route
    # since console route is using the reencrypt route without destination CA so we use it to check
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    And I use the "console" service
    And the expression should be true> service('console').annotation('service.alpha.openshift.io/serving-cert-secret-name') == "console-serving-cert" || service('console').annotation('service.beta.openshift.io/serving-cert-secret-name') == "console-serving-cert"

    Given I use the router project
    And all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | console.openshift-console.svc | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | required ca-file /var/run/configmaps/service-ca/service-ca.crt |

  # @author yadu@redhat.com
  # @case_id OCP-14678
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-14678:NetworkEdge Only the host in whitelist could access the route - unsecure route
    Given I have a project
    And I have a header test service in the project
    And evaluation of `"haproxy.router.openshift.io/ip_whitelist=#{cb.req_headers["x-forwarded-for"]}"` is stored in the :my_whitelist clipboard

    # Add another IP whitelist for route
    When I run the :annotate client command with:
      | resource     | route                                            |
      | resourcename | <%= cb.header_test_svc.name %>                   |
      | keyval       | haproxy.router.openshift.io/ip_whitelist=8.8.8.8 |
      | overwrite    | true                                             |
    Then the step should succeed

    # Access the route again waiting for the whitelist to apply
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the route
    Then the step should fail
    """

    # Add IP whitelist for route
    When I run the :annotate client command with:
      | resource     | route                          |
      | resourcename | <%= cb.header_test_svc.name %> |
      | keyval       | <%= cb.my_whitelist %>         |
      | overwrite    | true                           |
    Then the step should succeed

    # Access the route
    When I wait for a web server to become available via the route
    Then the output should contain "x-forwarded-for"

  # @author zzhao@redhat.com
  # @case_id OCP-15976
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-15976:NetworkEdge The edge route should support HSTS
    Given the master version >= "3.7"
    And I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And all pods in the project are ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name     | myroute          |
      | service  | service-unsecure |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                    |
      | resourcename | myroute                                                  |
      | keyval       | haproxy.router.openshift.io/hsts_header=max-age=31536000 |
    Then the step should succeed
    Given I use the "service-unsecure" service
    And I wait up to 20 seconds for the steps to pass:
    """
    When I wait for a secure web server to become available via the "myroute" route
    And the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:headers]["strict-transport-security"] == ["max-age=31536000"]
    """
    When I run the :annotate client command with:
      | resource     | route                                                                      |
      | resourcename | myroute                                                                    |
      | keyval       | haproxy.router.openshift.io/hsts_header=max-age=31536000;includeSubDomains |
      | overwrite    | true                                                                       |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    And I wait for a secure web server to become available via the "myroute" route
    And the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:headers]["strict-transport-security"] == ["max-age=31536000;includeSubDomains"]
    """

    When I run the :annotate client command with:
      | resource     | route                                                                         |
      | resourcename | myroute                                                                       |
      | keyval       | haproxy.router.openshift.io/hsts_header=max-age=100;includeSubDomains;preload |
      | overwrite    | true                                                                          |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    And I wait for a secure web server to become available via the "myroute" route
    And the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:headers]["strict-transport-security"] == ["max-age=100;includeSubDomains;preload"]
    """

  # @author zzhao@redhat.com
  # @case_id OCP-16368
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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
  Scenario: OCP-16368:NetworkEdge The reencrypt route should support HSTS
    Given the master version >= "3.7"
    And I have a project

    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run the :create client command with:
      | f | web-server-rc.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server-rc |

    # Create reencrypt route and add annotation to the route
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | reen-route              |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                                                         |
      | resourcename | reen-route                                                                    |
      | keyval       | haproxy.router.openshift.io/hsts_header=max-age=100;includeSubDomains;preload |
    Then the step should succeed

    Given I use the "service-secure" service
    And I wait up to 30 seconds for the steps to pass:
    """
    And I wait for a secure web server to become available via the "reen-route" route
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:headers]["strict-transport-security"] == ["max-age=100;includeSubDomains;preload"]
    """

