Feature: Testing haproxy rate limit related features

  # @author hongli@redhat.com
  # @case_id OCP-18482
  @admin
  Scenario Outline: limits backend pod max concurrent connections for unsecure, edge, reen route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/httpbin-pod.json |
    Then the step should succeed
    And the pod named "httpbin-pod" becomes ready
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard

    When I run the :create client command with:
      | f | <service> |
    Then the step should succeed
    When I run the :create client command with:
      | f | <route> |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route        |
      | resourcename | <route_name> |
      | keyval       | haproxy.router.openshift.io/pod-concurrent-connections=<pass_num> |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | grep | <%=cb.pod_ip %> | /var/lib/haproxy/conf/haproxy.config |
    Then the output should contain:
      | maxconn <pass_num> |
    """

    Examples:
      | route_type | route_name | service | route | resolve_str | url | pass_num | fail_num |
      | unsecure | route | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/unsecure/service_unsecure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json | unsecure.example.com:80 | http://unsecure.example.com | 1 | 3 |
      | edge | secured-edge-route | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/edge/service_unsecure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge.json | test-edge.example.com:443 | https://test-edge.example.com | 2 | 2 |
      | reen | route-reencrypt | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/reencrypt/service_secure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.json | test-reen.example.com:443 | https://test-reen.example.com | 3 | 1 |

