Feature: Testing haproxy router

  # @author zzhao@redhat.com
  # @case_id OCP-9736
  @admin
  Scenario: OCP-9736 HTTP response header should return for default haproxy 503
    Given I switch to cluster admin pseudo user
    And I use the router project
    And all default router pods become ready
    When I execute on the pod:
      | /usr/bin/curl | -v  | 127.0.0.1:80 |
    Then the output should contain "HTTP/1.0 503 Service Unavailable"

  # @author bmeng@redhat.com
  # @case_id OCP-11903
  @smoke
  Scenario: OCP-11903 haproxy cookies based sticky session for unsecure routes
    #create route and service which has two endpoints
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    Given I have a pod-for-ping in the project
    #access the route without cookies
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -c |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]
    """
    #access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ |
      | -b |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access == @result[:response]
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11130
  Scenario: OCP-11130 haproxy cookies based sticky session for edge termination routes
    #create route and service which has two endpoints
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | service | service-unsecure |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    #access the route without cookies
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -c |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    Given I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]
    """
    #access the route with cookies
    Given I run the steps 6 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
      | -b |
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access == @result[:response]
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11583
  @admin
  @destructive
  Scenario: OCP-11583 Router with specific ROUTE_LABELS will only work for specific routes
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTE_LABELS=router=router1 |

    Given I switch to the first user
    And I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem"
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | hostname | <%= rand_str(5, :dns) %>-edge.example.com |
      | service | service-unsecure |
      | cert | route_edge-www.edge.com.crt |
      | key | route_edge-www.edge.com.key |
      | cacert | ca.pem |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I open web server via the "http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/" url
    Then the output should not contain "Hello-OpenShift"
    When I execute on the "hello-pod" pod:
      | curl |
      | -sS |
      | --resolve |
      | <%= route("route-edge", service("route-edge")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should not contain "Hello-OpenShift"

    When I run the :label client command with:
      | resource | route |
      | name | service-unsecure |
      | key_val | router=router1 |
    Then the step should succeed
    And I wait up to 15 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/" url
    Then the output should contain "Hello-OpenShift"
    """
    When I run the :label client command with:
      | resource | route |
      | name | route-edge |
      | key_val | router=router1 |
    Then the step should succeed
    And I wait up to 15 seconds for the steps to pass:
    """
    When I execute on the "hello-pod" pod:
      | curl |
      | -sS |
      | --resolve |
      | <%= route("route-edge", service("route-edge")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-edge", service("route-edge")).dns(by: user) %>/ |
      | -k |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-11549
  @admin
  @destructive
  Scenario: OCP-11549 Haproxy router health check will use 1936 port if user disable the stats port
    Given I switch to cluster admin pseudo user
    And I use the router project
    And default router image is stored into the :default_router_image clipboard
    And all default router pods become ready
    Given default router replica count is restored after scenario
    And admin ensures "tc-516836" dc is deleted after scenario
    And admin ensures "tc-516836" service is deleted after scenario
    When I run the :scale client command with:
      | resource | dc |
      | name | router |
      | replicas | 0 |
    Then the step should succeed
    When I run the :oadm_router admin command with:
      | name | tc-516836 |
      | images | <%= cb.default_router_image %> |
      | stats_port | 0 |
      | service_account | router |
      | selector | router=enabled |
    And a pod becomes ready with labels:
      | deploymentconfig=tc-516836 |
    When I execute on the pod:
      | /usr/bin/curl | -sS | -w | %{http_code} | 127.0.0.1:1936/healthz |
    Then the output should contain "200"

  # @author zzhao@redhat.com
  # @case_id OCP-12651
  @admin
  @destructive
  Scenario: OCP-12651 The route auto generated can be accessed using the default cert
    Given I switch to cluster admin pseudo user
    And I use the router project
    And default router image is stored into the :default_router_image clipboard
    Given default router replica count is restored after scenario
    And admin ensures "ocp-12651" dc is deleted after scenario
    And admin ensures "ocp-12651" service is deleted after scenario
    When I run the :scale client command with:
      | resource | dc |
      | name | router |
      | replicas | 0 |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/default-router.pem"
    When I run the :oadm_router admin command with:
      | name | ocp-12651|
      | images | <%= cb.default_router_image %> |
      | default_cert | default-router.pem |
      | selector | router=enabled |
    And a pod becomes ready with labels:
      | deploymentconfig=ocp-12651|
    And evaluation of `pod.ip` is stored in the :custom_router_ip clipboard

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | service | service-unsecure |
      | hostname | <%= rand_str(5, :dns) %>-edge.example.com |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/default-router.pem |
      | -O |
      | /tmp/default-router.pem |
      | -T |
      | 10 |
      | -t |
      | 3  |
    Then the step should succeed
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= route("route-edge", service("service-unsecure")).dns(by: user) %>:443:<%= cb.custom_router_ip %> |
      | https://<%= route("route-edge", service("service-unsecure")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/default-router.pem |
    Then the output should contain "Hello-OpenShift"

  # @author yadu@redhat.com
  # @case_id OCP-11236
  @admin
  @destructive
  Scenario: OCP-11236 Set reload time for haproxy router script - Create routes
    # prepare router
    Given default router is disabled and replaced by a duplicate
    And I switch to cluster admin pseudo user
    And I use the router project
    When I run the :env admin command with:
      | resource | dc/<%= cb.new_router_dc.name %>         |
      | e        | RELOAD_INTERVAL=90s                     |
    Then the step should succeed
    And I wait until replicationController "<%= cb.new_router_dc.name %>-2" is ready

    # prepare services
    Given I switch to the default user
    And I have a project
    And I have a pod-for-ping in the project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
    Then the step should succeed

    # create some route and wait for it to be sure we hit a reload point
    When I expose the "service-unsecure" service
    Then the step should succeed
    And I wait up to 95 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                                                   |
      | -ksS                                                   |
      | --resolve                                              |
      | <%= route("service-unsecure").dns(by: user) %>:80:<%= cb.router_ip[0] %> |
      | http://<%= route("service-unsecure").dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """
    # it is important to use one and the same router
    # And I wait for a web server to become available via the "service-unsecure" route

    # create route and check changes not applied before RELOAD_INTERVAL reached
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed

    And I repeat the steps up to 70 seconds:
    """
    When I execute on the "<%= cb.ping_pod.name %>" pod:
      | curl      |
      | -ksS      |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should not contain "Hello-OpenShift"
    """
    And I wait up to 50 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl      |
      | -ksS      |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """
    When I run the :delete client command with:
      | object_type       | route      |
      | object_name_or_id | edge-route |
    Then the step should succeed
    And I repeat the steps up to 70 seconds:
    """
    When I execute on the pod:
      | curl      |
      | -ksS      |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """
    And I wait up to 50 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl      |
      | -ksS      |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
    Then the step should succeed
    And the output should not contain "Hello-OpenShift"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-11619
  Scenario: OCP-11619 Limit the number of TCP connection per IP in specified time period
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name | route-pass |
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
      | keyval | haproxy.router.openshift.io/rate-limit-connections.rate-tcp=5 |
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
  Scenario: OCP-15044 The backend health check interval of unsecure route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/list_for_caddy.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-pods |
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
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 200ms |
    """

  # @author hongli@redhat.com
  # @case_id OCP-15049
  @admin
  Scenario: OCP-15049 The backend health check interval of edge route can be set by annotation
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/list_for_caddy.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-pods |
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
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | check inter 300ms |
    """

  # @author bmeng@redhat.com
  # @case_id OCP-10043
  Scenario: OCP-10043 Set balance leastconn for passthrough routes
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name | route-pass |
      | service | service-secure |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource | route |
      | resourcename | route-pass |
      | keyval | haproxy.router.openshift.io/balance=leastconn |
      | overwrite | true |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And I use the "service-secure" service
    When I execute on the pod:
      | curl                                                   |
      | -ksS                                                   |
      | --resolve                                              |
      | <%= route("route-pass").dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-pass").dns(by: user) %> |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And evaluation of `@result[:response]` is stored in the :first_access clipboard
    When I execute on the pod:
      | curl                                                   |
      | -ksS                                                   |
      | --resolve                                              |
      | <%= route("route-pass").dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-pass").dns(by: user) %> |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the expression should be true> cb.first_access != @result[:response]

  # @author yadu@redhat.com
  # @case_id OCP-11679
  Scenario: OCP-11679 Disable haproxy hash based sticky session for unsecure routes
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
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
      | /tmp/cookies |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    When I execute on the pod:
      | bash | -c | for i in {1..10} ; do curl -sS  http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/ -b /tmp/cookies ; done |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift-1 |
      | Hello-OpenShift-2 |

  # @author hongli@redhat.com
  # @case_id OCP-11437
  @admin
  @destructive
  Scenario: OCP-11437 the routes should be loaded on initial sync
    Given I have a project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    Given I have a pod-for-ping in the project

    Given admin ensures new router pod becomes ready after following env added:
      | RELOAD_INTERVAL=122s |
    And evaluation of `pod.ip` is stored in the :router_ip clipboard

    # the route should be accessed in less than RELOAD_INTERVAL(122s) after router pod redeployed
    Given I switch to the first user
    And I use the "<%= cb.proj_name %>" project
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "hello-pod" pod:
      | curl |
      | -ksS |
      | --resolve |
      | <%= route("service-unsecure").dns(by: user) %>:80:<%= cb.router_ip[0] %> |
      | http://<%= route("service-unsecure").dns(by: user) %>/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-12923
  @admin
  @destructive
  Scenario: OCP-12923 same host with different path can be admitted
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_DISABLE_NAMESPACE_OWNERSHIP_CHECK=true  |

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | service          |
      | resource_name | service-unsecure |
      | path          | /test            |
    Then the step should succeed
    Given evaluation of `route("service-unsecure", service("service-unsecure")).dns(by: user)` is stored in the :unsecure clipboard

    #change another namespace and create one same hostname stored in ':unsecure' with different path '/path/second'
    Given I switch to the second user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | service             |
      | resource_name | service-unsecure    |
      | hostname      | <%= cb.unsecure %>  |
      | path          | /path/second        |
    Then the step should succeed

    Given I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= cb.unsecure %>/test/" url
    Then the output should contain "Hello-OpenShift-Path-Test"
    """
    Given I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= cb.unsecure %>/path/second/" url
    Then the output should contain "second-test http-8080"
    """
    #create one overlap path '/path' with above to verify it also can work
    When I run the :expose client command with:
      | resource      | service            |
      | resource_name | service-unsecure   |
      | hostname      | <%= cb.unsecure %> |
      | path          | /path              |
      | name          | path               |
    Then the step should succeed

    Given I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= cb.unsecure %>/path/" url
    Then the output should contain "ocp-test http-8080"
    """

    #Create one same hostname without path,the route can be cliamed.
    When I run the :expose client command with:
      | resource      | service            |
      | resource_name | service-unsecure   |
      | hostname      | <%= cb.unsecure %> |
      | name          | withoutpath        |
    Then the step should succeed

    Given I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= cb.unsecure %>" url
    Then the output should contain "Hello-OpenShift-1 http-8080"
    """
    # All routes in this namespaces should be cliamed till now.
    When I run the :get client command with:
      | resource | route |
    Then the step should succeed
    And the output should not contain "HostAlreadyClaimed"

    #Create one same hostname and same path with first user. the route will be marked as 'HostAlreadyCliamed'
    When I run the :expose client command with:
      | resource      | service            |
      | resource_name | service-unsecure   |
      | hostname      | <%= cb.unsecure %> |
      | path          | /test              |
      | name          | same               |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | route |
      | resource_name | same  |
    Then the step should succeed
    And the output should contain "HostAlreadyClaimed"

  # @author hongli@redhat.com
  # @case_id OCP-15872
  Scenario: OCP-15872 can set cookie name for unsecure routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
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
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "unsecure-cookie_1"}
    """
    And evaluation of `@result[:response]` is stored in the :first_access clipboard

    #access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I wait for a web server to become available via the "service-unsecure" route
    Then the expression should be true> cb.first_access == @result[:response]
    """

  # @author hongli@redhat.com
  # @case_id OCP-15873
  Scenario: OCP-15873 can set cookie name for edge routes by annotation
    #create route and service which has two endpoints
    Given the master version >= "3.7"
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json |
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
    Then the output should contain "Hello-OpenShift"
    And the expression should be true> @result[:cookies].any? {|c| c.name == "2-edge_cookie"}
    """
    And evaluation of `@result[:response]` is stored in the :first_access clipboard

    #access the route with cookies
    Given HTTP cookies from result are used in further request
    Given I run the steps 6 times:
    """
    When I wait for a secure web server to become available via the "edge-route" route
    And the expression should be true> cb.first_access == @result[:response]
    """

  # @author zzhao@redhat.com
  # @case_id OCP-15457
  @admin
  @destructive
  Scenario: OCP-15457 The router configuration should be loaded immediately after the namespace label added
    Given the master version >= "3.7"
    Given admin ensures new router pod becomes ready after following env added:
      | NAMESPACE_LABELS=team=red |

    Given I have a project
    And evaluation of `project.name` is stored in the :project_red clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed

    When I run the :label admin command with:
      | resource | namespaces            |
      | name     | <%= cb.project_red %> |
      | key_val  | team=red              |
    Then the step should succeed
    When I wait up to 15 seconds for a web server to become available via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift"

    #updated the namespace with label 'team=blue', then the route will not be accessed.
    When I run the :label admin command with:
      | resource  | namespaces             |
      | name      | <%= cb.project_red %>  |
      | key_val   | team=blue              |
      | overwrite | true                   |
    Then the step should succeed
    Given 10 seconds have passed
    And I run the steps 3 times:
    """
    When I open web server via the "service-unsecure" route
    Then the step should fail
    And the output should not contain "Hello-OpenShift"
    """
    #updated the namespace label back to 'team=red'
    When I run the :label admin command with:
      | resource  | namespaces            |
      | name      | <%= cb.project_red %> |
      | key_val   | team=red              |
      | overwrite | true                  |
    Then the step should succeed
    When I wait up to 15 seconds for a web server to become available via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift"

