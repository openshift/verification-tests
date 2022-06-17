Feature: Testing HAProxy router logging related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-19830
  @admin
  @destructive
  Scenario: OCP-19830 deploy haproxy router with an rsyslog sidecar container
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    And default router image is stored into the :default_router_image clipboard
    Given default router replica count is restored after scenario
    And admin ensures "ocp-19830" dc is deleted after scenario
    And admin ensures "ocp-19830" service is deleted after scenario
    When I run the :scale client command with:
      | resource | dc     |
      | name     | router |
      | replicas | 0      |
    Then the step should succeed

    # create new router with extended-logging enabled and set ROUTER_LOG_LEVEL to debug
    When I run the :oadm_router admin command with:
      | name             | ocp-19830                      |
      | images           | <%= cb.default_router_image %> |
      | extended_logging | true                           |
      | service_account  | router                         |
      | selector         | router=enabled                 |
    And a pod becomes ready with labels:
      | deploymentconfig=ocp-19830 |
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    When I run the :env client command with:
      | resource | dc/ocp-19830 |
      | e        | ROUTER_LOG_LEVEL=debug |
    Then the step should succeed
    And I wait for the pod named "<%= cb.router_pod %>" to die
    And a pod becomes ready with labels:
      | deploymentconfig=ocp-19830 |
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    # create a route and access the route
    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I wait up to 15 seconds for a web server to become available via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift"

    # check access logs in syslog container
    Given I switch to cluster admin pseudo user
    And I use the router project
    When I run the :logs client command with:
      | resource_name | <%= cb.router_pod %> |
      | c             | syslog               |
    Then the output should match:
      | haproxy.*service-unsecure/pod:caddy-docker:service-unsecure:\d+.\d+.\d+.\d+:8080 \d+/\d+/\d+/\d+/\d+ 200.*GET / HTTP/ |

