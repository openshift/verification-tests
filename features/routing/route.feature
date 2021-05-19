Feature: Testing route

  # @author zzhao@redhat.com
  # @case_id OCP-12122
  @smoke
  Scenario: Alias will be invalid after removing it
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/header-test/dc.json |
    Then the step should succeed
    When I run the :create client command with:
      | f  |   https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/insecure-service.json |
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

  # @author yadu@redhat.com
  # @case_id OCP-10660
  @smoke
  Scenario: Service endpoint can be work well if the mapping pod ip is updated
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/networking/list_for_pods.json" replacing paths:
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

  # @author zzhao@redhat.com
  # @case_id OCP-12652
  @smoke
  Scenario: The later route should be HostAlreadyClaimed when there is a same host exist
    Given I have a project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json  |
    Then the step should succeed
    Given I create a new project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | route  |
      | resource_name | route  |
    Then the output should contain "HostAlreadyClaimed"

  # @author bmeng@redhat.com
  # @case_id OCP-12472
  @smoke
  Scenario: Edge terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem"

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | hostname | <%= rand_str(5, :dns) %>-edge.example.com |
      | service | service-unsecure |
      | cert | route_edge-www.edge.com.crt |
      | key | route_edge-www.edge.com.key |
      | cacert | ca.pem |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("route-edge", service("route-edge")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
      | -c |
      | /tmp/cookie.txt|
    Then the output should contain "Hello-OpenShift"
    """
    When I execute on the pod:
      | cat |
      | /tmp/cookie.txt |
    Then the step should succeed
    And the output should not contain "OPENSHIFT"
    And the output should not match "\d+\.\d+\.\d+\.\d+"

  # @author bmeng@redhat.com
  # @case_id OCP-12477
  Scenario: Passthrough terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I run the :create_route_passthrough client command with:
      | name | passthrough-route |
      | hostname | <%= rand_str(5, :dns) %>-pass.example.com |
      | service | service-secure |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("passthrough-route", service("passthrough-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("passthrough-route", service("passthrough-route")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-12481
  Scenario: Reencrypt terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.ca"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I run the :create_route_reencrypt client command with:
      | name | route-reencrypt |
      | hostname | <%= rand_str(5, :dns) %>-reen.example.com |
      | service | service-secure |
      | cert | route_reencrypt-reen.example.com.crt |
      | key | route_reencrypt-reen.example.com.key |
      | cacert | route_reencrypt.ca |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
      | -c |
      | /tmp/cookie.txt|
    Then the output should contain "Hello-OpenShift"
    """
    When I execute on the pod:
      | cat |
      | /tmp/cookie.txt |
    Then the step should succeed
    And the output should not contain "OPENSHIFT"
    And the output should not match "\d+\.\d+\.\d+\.\d+"

  # @author zzhao@redhat.com
  # @case_id OCP-12562
  Scenario: The path specified in route can work well for edge terminated
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I run the :create_route_edge client command with:
      | name | edge-route |
      | service | service-unsecure |
      | path| /test |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/test/ |
      | -c |
      | /tmp/cookie.txt |
      | -k |
    Then the output should contain "Hello-OpenShift-Path-Test"
    """
    When I execute on the pod:
      | curl |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
      | -k |
    Then the output should contain "Application is not available"
    When I execute on the pod:
      | cat |
      | /tmp/cookie.txt |
    Then the step should succeed
    And the output should not contain "OPENSHIFT"
    And the output should not match "\d+\.\d+\.\d+\.\d+"

  # @author zzhao@redhat.com
  # @case_id OCP-12564
  @smoke
  Scenario: The path specified in route can work well for reencrypt terminated
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.ca"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I run the :create_route_reencrypt client command with:
      | name | route-recrypt |
      | hostname | <%= rand_str(5, :dns) %>-reen.example.com |
      | service | service-secure |
      | cert | route_reencrypt-reen.example.com.crt |
      | key | route_reencrypt-reen.example.com.key |
      | cacert | route_reencrypt.ca |
      | destcacert | route_reencrypt_dest.ca |
      | path | /test |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/test/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift-Path-Test"
    """
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Application is not available"

  # @author yadu@redhat.com
  # @case_id OCP-9651
  Scenario: Config insecureEdgeTerminationPolicy to Redirect for route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
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
    Given I have a pod-for-ping in the project
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
      | Location: https:// |

  # @author yadu@redhat.com
  # @case_id OCP-9650
  Scenario: Config insecureEdgeTerminationPolicy to Allow for route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
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
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl                                                                                          |
      | --resolve                                                                                     |
      | <%= route("myroute", service("service-unsecure")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/                   |
      | -k                                                                                            |
      | -v                                                                                            |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 200    |
    And the output should not contain:
      | HTTP/1.1 302 Found |
    When I execute on the pod:
      | curl                                                                                         |
      | --resolve                                                                                    |
      | <%= route("myroute", service("service-unsecure")).dns(by: user) %>:80:<%= cb.router_ip[0] %> |
      | http://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/                   |
      | -v                                                                                           |
      | -c                                                                                           |
      | /tmp/cookie                                                                                  |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 200    |
    And the output should not contain:
      | HTTP/1.1 302 Found |
    And I execute on the pod:
      | cat |
      | /tmp/cookie |
    Then the step should succeed
    And the output should match:
      | FALSE.*FALSE |

  # @author yadu@redhat.com
  # @case_id OCP-12635
  Scenario: Enabled Active/Active routers can do round-robin on multiple target IPs
    # The case need to run on multi-node env
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    Then the expression should be true> cb.router_ip.size > 1
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name     | edge-route       |
      | service  | service-unsecure |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl                                                                                       |
      | --resolve                                                                                  |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/                   |
      | -k                                                                                         |
    Then the step should succeed
    Then the output should contain "Hello-OpenShift"
    When I execute on the pod:
      | curl                                                                                       |
      | --resolve                                                                                  |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[1] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/                   |
      | -k                                                                                         |
    Then the step should succeed
    Then the output should contain "Hello-OpenShift"

  # @author yadu@redhat.com
  # @case_id OCP-10024
  @smoke
  Scenario: Route could NOT be updated after created
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc470732/route_withouthost1.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | route                                   |
      | resource_name | service-unsecure1                       |
      | p             | {"spec":{"host":"www.changeroute.com"}} |
    Then the output should contain:
      | spec.host: Invalid value: "www.changeroute.com": field is immutable |

  # @author zzhao@redhat.com
  # @case_id OCP-11036
  Scenario: Set insecureEdgeTerminationPolicy to Redirect for passthrough route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
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
    Given I have a pod-for-ping in the project
    And I wait up to 20 seconds for the steps to pass:
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
      | Location: https:// |
    """
    When I run the :patch client command with:
      | resource      | route              |
      | resource_name | myroute            |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Allow"}}} |
    Then the step should fail
    And the output should contain "acceptable values are None, Redirect, or empty"

  # @author zzhao@redhat.com
  # @case_id OCP-11839
  Scenario: Set insecureEdgeTerminationPolicy to Redirect and Allow for reencrypt route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed

    #create reencrypt termination route
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | reen |
      | service    | service-secure     |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
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
      | Location: https:// |
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
  Scenario: The hostname should be converted to available route when met special character
    Given I have a project
    When I run the :create client command with:
      | f  |   https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed

    # test those 4 kind of route. When creating route which name have '.', it will be decoded to '-'.
    When I run the :expose client command with:
      | resource      | service              |
      | resource_name | service-unsecure     |
      | name          | unsecure.test        |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name     | edge.test        |
      | service  | service-unsecure |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name     | pass.test        |
      | service  | service-unsecure |
    Then the step should succeed
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
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
  Scenario: Check the cookie if using secure mode when insecureEdgeTerminationPolicy to Redirect for edge/reencrypt route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    # Create edge termination route
    When I run the :create_route_edge client command with:
      | name     | myroute           |
      | service  | service-unsecure  |
      | insecure_policy | Redirect   |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("myroute", service("service-unsecure")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /tmp/cookie |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | Location: https:// |
    And I execute on the pod:
      | cat |
      | /tmp/cookie |
    Then the step should succeed
    And the output should match:
      | FALSE.*TRUE |

    #create reencrypt termination route
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | reen                    |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
      | insecure_policy | Redirect           |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -v |
      | -L |
      | http://<%= route("reen", service("service-secure")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /tmp/cookie-reen |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |
      | HTTP/1.1 302 Found |
      | Location: https:// |
    """
    And I execute on the pod:
      | cat |
      | /tmp/cookie-reen |
    Then the step should succeed
    And the output should match:
      | FALSE.*TRUE |

  # @author zzhao@redhat.com
  # @case_id OCP-14059
  Scenario: Use the default destination CA of router if the route does not specify one for reencrypt route
    Given I have a project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/reencrypt-without-all-cert.yaml |
    Then the step should succeed
    And I pry
    And all pods in the project are ready
    Given I use the "service-secure" service
    When I wait up to 20 seconds for a secure web server to become available via the "route-reencrypt" route
    And the output should contain "Hello-OpenShift"

  # @author yadu@redhat.com
  # @case_id OCP-14678
  Scenario: Only the host in whitelist could access the route - unsecure route
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
    And expression should be true> @result[:exitstatus] == -1
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
  Scenario: The edge route should support HSTS
    Given the master version >= "3.7"
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
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
  Scenario: The reencrypt route should support HSTS
    Given the master version >= "3.7"
    And I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/reencrypt-without-all-cert.yaml" replacing paths:
      | ["items"][0]["metadata"]["annotations"] | { haproxy.router.openshift.io/hsts_header: "max-age=100;includeSubDomains;preload" } |
    Then the step should succeed
    And all pods in the project are ready

    Given I use the "service-secure" service
    And I wait up to 20 seconds for a secure web server to become available via the "route-reencrypt" route
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:headers]["strict-transport-security"] == ["max-age=100;includeSubDomains;preload"]

