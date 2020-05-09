Feature: Routes related features on web console

  # @author yapei@redhat.com
  # @case_id OCP-12294
  Scenario: Create route with invalid name and hostname on web console
    Given I create a new project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/authorization/scc/pod_requests_nothing.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/routing/unsecure/service_unsecure.json |
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
