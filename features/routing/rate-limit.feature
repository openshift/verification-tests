Feature: Testing haproxy rate limit related features

  # @author hongli@redhat.com
  # @case_id OCP-18482
  @admin
  Scenario: limits backend pod max concurrent connections for unsecure, edge, reen route
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "routing/routetimeout/httpbin-pod.json"
    When I run the :create client command with:
      | f | httpbin-pod.json |
    Then the step should succeed
    And the pod named "httpbin-pod" becomes ready
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard

    Given I obtain test data file "routing/routetimeout/service_unsecure.json"
    Given I obtain test data file "routing/routetimeout/service_secure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
      | f | service_secure.json   |
    Then the step should succeed

    Given I obtain test data file "routing/routetimeout/unsecure-route.json"
    Given I obtain test data file "routing/routetimeout/edge-route_edge.json"
    Given I obtain test data file "routing/routetimeout/reencrypt-route_reencrypt.json"
    When I run the :create client command with:
      | f | unsecure-route.json            |
      | f | edge-route_edge.json           |
      | f | reencrypt-route_reencrypt.json |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                                    |
      | resourcename | unsecure-route                                           |
      | keyval       | haproxy.router.openshift.io/pod-concurrent-connections=1 |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                                    |
      | resourcename | secured-edge-route                                       |
      | keyval       | haproxy.router.openshift.io/pod-concurrent-connections=2 |
    Then the step should succeed

    When I run the :annotate client command with:
      | resource     | route                                                    |
      | resourcename | route-reencrypt                                          |
      | keyval       | haproxy.router.openshift.io/pod-concurrent-connections=3 |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the router project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%=cb.router_pod %>" pod:
      | bash | -lc | grep -w "<%= cb.proj_name %>:unsecure-route" haproxy.config -A15 \| grep <%=cb.pod_ip %> |
    Then the output should contain:
      | maxconn 1 |
    When I execute on the "<%=cb.router_pod %>" pod:
      | bash | -lc | grep -w "<%= cb.proj_name %>:secured-edge-route" haproxy.config -A15 \| grep <%=cb.pod_ip %> |
    Then the output should contain:
      | maxconn 2 |
    When I execute on the "<%=cb.router_pod %>" pod:
      | bash | -lc | grep -w  "<%= cb.proj_name %>:route-reencrypt" haproxy.config -A15 \| grep <%=cb.pod_ip %> |
    Then the output should contain:
      | maxconn 3 |
    """
