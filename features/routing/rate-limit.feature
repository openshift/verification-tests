Feature: Testing haproxy rate limit related features

  # @author hongli@redhat.com
  # @case_id OCP-18482
  Scenario Outline: limits backend pod max concurrent connections for unsecure, edge, reen route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/httpbin-pod.json |
    Then the step should succeed
    And the pod named "httpbin-pod" becomes ready

    When I run the :create client command with:
      | f | <service> |
    Then the step should succeed
    When I run the :create client command with:
      | f | <route> |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | bash | -c | for i in {1..4} ; do curl -sS --resolve <resolve_str>:<%= cb.router_ip[0] %> <url>/delay/6 -k -I & done |
    Then the step should succeed
    And the output should contain 4 times:
      | 200 OK |

    When I run the :annotate client command with:
      | resource     | route        |
      | resourcename | <route_name> |
      | keyval       | haproxy.router.openshift.io/pod-concurrent-connections=<pass_num> |
    Then the step should succeed
    When I execute on the pod:
      | bash | -c | for i in {1..4} ; do curl -sS --resolve <resolve_str>:<%= cb.router_ip[0] %> <url>/delay/6 -k -I & done |
    Then the step should succeed
    And the output should contain <pass_num> times:
      | 200 OK |
    And the output should contain <fail_num> times:
      | 503 Service Unavailable |

    Examples:
      | route_type | route_name | service | route | resolve_str | url | pass_num | fail_num |
      | unsecure | route | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/unsecure/service_unsecure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json | unsecure.example.com:80 | http://unsecure.example.com | 1 | 3 |
      | edge | secured-edge-route | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/edge/service_unsecure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge.json | test-edge.example.com:443 | https://test-edge.example.com | 2 | 2 |
      | reen | route-reencrypt | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/reencrypt/service_secure.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.json | test-reen.example.com:443 | https://test-reen.example.com | 3 | 1 |

