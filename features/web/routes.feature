Feature: Routes related features on web console

  # @author yapei@redhat.com
  # @case_id OCP-12294
  Scenario: OCP-12294 Create route with invalid name and hostname on web console
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_nothing.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I perform the :open_create_route_page_from_service_page web console action with:
      | project_name | <%= project.name%> |
      | service_name | service-unsecure   |
    Then the step should succeed
    # set route name to invalid
    When I perform the :set_route_name web console action with:
      | route_name | GF-s68q |
    Then the step should succeed
    When I get the "disabled" attribute of the "button" web element:
      | text | Create |
    Then the output should contain "true"
    # set route host to invalid
    When I perform the :set_route_name web console action with:
      | route_name | testroute |
    Then the step should succeed
    When I perform the :set_hostname web console action with:
      | hostname | ah#$G |
    Then the step should succeed
    When I get the "disabled" attribute of the "button" web element:
      | text | Create |
    Then the output should contain "true"

  # @author yapei@redhat.com
  # @case_id OCP-11210
  Scenario: OCP-11210 Add path when creating edge terminated route on web console
    Given I create a new project

    # create pod, service and pod used for curl command
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed

    # create edge route with path on web console
    When I perform the :open_create_route_page_from_service_page web console action with:
      | project_name | <%= project.name%> |
      | service_name | service-unsecure   |
    Then the step should succeed
    When I perform the :create_route_with_path_and_policy_for_insecure_traffic web console action with:
      | route_name              | edgepathroute   |
      | path                    | /test           |
      | target_port             | 8080            |
      | tls_termination_type    | Edge            |
      | insecure_traffic_policy | None            |
    Then the step should succeed

    # check route function
    When I access the "https://<%= route("edgepathroute", service("edgepathroute")).dns %>/test/" url in the web browser
    Then the step should succeed
    When I perform the :check_response_string web console action with:
      | response_string | Hello-OpenShift-Path-Test |
    Then the step should succeed
    When I access the "https://<%= route("edgepathroute", service("edgepathroute")).dns %>/" url in the web browser
    Then the step should succeed
    When I perform the :check_response_string web console action with:
      | response_string | Application is not available |
    Then the step should succeed
    When I access the "https://<%= route("edgepathroute", service("edgepathroute")).dns %>/none" url in the web browser
    Then the step should succeed
    When I perform the :check_response_string web console action with:
      | response_string | Application is not available |
    Then the step should succeed

