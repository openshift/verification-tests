Feature: Testing HAProxy dynamic configuration manager related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-19863
  @admin
  @destructive
  Scenario: OCP-19863 unsecured route support haproxy dynamic changes
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_HAPROXY_CONFIG_MANAGER=true |
    And the last reload log of a router pod is stored in :reload_1 clipboard

    # create unsecure route and it should be accessed immediately
    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json  |
    Then the step should succeed
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I open web server via the "service-unsecure" route
    Then the output should contain "Hello-OpenShift"

    # check the router log again and ensure no reloaded
    Given I switch to cluster admin pseudo user
    And the last reload log of a router pod is stored in :reload_2 clipboard
    And the expression should be true> cb.reload_2 == cb.reload_1

  # @author hongli@redhat.com
  # @case_id OCP-19864
  @admin
  @destructive
  Scenario: OCP-19864 edge route support haproxy dynamic changes
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_HAPROXY_CONFIG_MANAGER=true |
    And the last reload log of a router pod is stored in :reload_1 clipboard

    # create edge route and it should be accessed immediately
    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/service_unsecure.json  |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed
    When I open secure web server via the "edge-route" route
    Then the output should contain "Hello-OpenShift"

    # check the router log again and ensure no reloaded
    Given I switch to cluster admin pseudo user
    And the last reload log of a router pod is stored in :reload_2 clipboard
    And the expression should be true> cb.reload_2 == cb.reload_1

  # @author hongli@redhat.com
  # @case_id OCP-19865
  @admin
  @destructive
  Scenario: OCP-19865 passthrough route support haproxy dynamic changes
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_HAPROXY_CONFIG_MANAGER=true |
    And the last reload log of a router pod is stored in :reload_1 clipboard

    # create passthrough route and it should be accessed immediately
    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=caddy-docker |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json  |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name    | pass-route     |
      | service | service-secure |
    Then the step should succeed
    When I open secure web server via the "pass-route" route
    Then the output should contain "Hello-OpenShift"

    # check the router log again and ensure no reloaded
    Given I switch to cluster admin pseudo user
    And the last reload log of a router pod is stored in :reload_2 clipboard
    And the expression should be true> cb.reload_2 == cb.reload_1

