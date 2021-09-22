Feature: Testing timeout route

  # @author yadu@redhat.com
  # @case_id OCP-11635
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  @aws-upi
  Scenario: Set timeout server for passthough route
    Given I have a project
    And I store an available router IP in the :router_ip clipboard
    Given I obtain test data file "routing/routetimeout/httpbin-pod-2.json"
    When I run the :create client command with:
      | f  | httpbin-pod-2.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=httpbin-pod |
    Given I obtain test data file "routing/routetimeout/passthough/service_secure.json"
    When I run the :create client command with:
      | f  | service_secure.json |
    Then the step should succeed
    Given I wait for the "service-secure" service to become ready
    When I run the :create_route_passthrough client command with:
      | name     | pass-route       |
      | service  | service-secure |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource         | route                                  |
      | resourcename     | pass-route                             |
      | overwrite        | true                                   |
      | keyval           | haproxy.router.openshift.io/timeout=3s |
    Then the step should succeed
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl                                                                                       |
      | --resolve                                                                                  |
      | <%= route("pass-route", service("pass-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("pass-route", service("pass-route")).dns(by: user) %>/delay/2            |
      | -k                                                                                         |
    Then the step should succeed
    Then the output should contain:
      | "Host": "pass-route |
      | delay/2             |
    When I execute on the pod:
      | curl                                                                                       |
      | -Iv                                                                                        |
      | --resolve                                                                                  |
      | <%= route("pass-route", service("pass-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("pass-route", service("pass-route")).dns(by: user) %>/delay/4            |
      | -k                                                                                         |
    Then the step should fail
    Then the output should contain "Empty reply from server"

