Feature: Testing wildcard routes

  # @author bmeng@redhat.com
  @admin
  @destructive
  Scenario Outline: Create wildcard domain routes
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_ALLOW_WILDCARD_ROUTES=true |

    Given I switch to the first user
    And I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/routing/wildcard_route/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/routing/<service> |
    Then the step should succeed
    When I run the :create client command with:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/routing/wildcard_route/<route> |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    When I execute on the pod:
      | curl |
      | --resolve |
      | wildcard.<route-suffix>:443:<%= cb.router_ip[0] %> |
      | https://wildcard.<route-suffix>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    Given an 8 characters random string of type :dns952 is stored into the :wildcard_route clipboard
    When I execute on the pod:
      | curl |
      | --resolve |
      | <%= cb.wildcard_route %>.<route-suffix>:443:<%= cb.router_ip[0] %> |
      | https://<%= cb.wildcard_route %>.<route-suffix>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"

    Examples:
      | route_type  | service                         | route                | route-suffix     |
      | edge        | edge/service_unsecure.json      | route_edge.json      | edge.example.com | # @case_id OCP-11403
      | reencrypt   | reencrypt/service_secure.json   | route_reencrypt.json | reen.example.com | # @case_id OCP-11855
      | passthrough | passthrough/service_secure.json | route_pass.json      | pass.example.com | # @case_id OCP-11671

