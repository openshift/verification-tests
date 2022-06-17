Feature: services related feature on web console

  # @author wsun@redhat.com
  # @case_id OCP-10602
  Scenario: OCP-10602 Access service pages from web console
    Given I have a project
    # oc process -f file | oc create -f -
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc477695/hello.json"
    Then the step should succeed
    When I perform the :check_service_list_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
    Then the step should succeed
    Given evaluation of `route("hello-route").dns` is stored in the :dns1 clipboard
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %>             |
      | service_name | hello-service                   |
      | selectors    | name=hello-pod                  |
      | type         | ClusterIP                       |
      | routes       | http://<%= cb.dns1 %>/testpath1 |
      | target_port  | 5555                            |
    Then the step should succeed
    When I replace resource "route" named "hello-route":
      | testpath1 | testpath2 |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %>              |
      | service_name | hello-service                    |
      | selectors    | name=hello-pod                   |
      | type         | ClusterIP                        |
      | routes       | http://<%= cb.dns1 %>/testpath2  |
      | target_port  | 5555                             |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc477695/new_route.json |
    Then the step should succeed
    Given evaluation of `route("hello-route1").dns` is stored in the :dns2 clipboard
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %>        |
      | service_name | hello-service              |
      | selectors    | name=hello-pod             |
      | type         | ClusterIP                  |
      | routes       | http://<%= cb.dns2 %>      |
      | target_port  | 5555                       |
    Then the step should succeed
    Given I ensure "hello-route" route is deleted
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %>   |
      | service_name | hello-service         |
      | selectors    | name=hello-pod        |
      | type         | ClusterIP             |
      | routes       | http://<%= cb.dns2 %> |
      | target_port  | 5555                  |
    Then the step should succeed
    When I replace resource "service" named "hello-service":
      | 5555 | 5556 |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %>     |
      | service_name | hello-service           |
      | selectors    | name=hello-pod          |
      | type         | ClusterIP               |
      | routes       | http://<%= cb.dns2 %>   |
      | target_port  | 5556                    |
    Then the step should succeed
    Given I ensure "hello-service" service is deleted
    When I perform the :check_deleted_service web console action with:
      | project_name    | <%= project.name %>                     |
      | service_name    | hello-service                           |
      | service_warning | The service details could not be loaded |
    Then the step should succeed

  # @author etrott@redhat.com
  # @case_id OCP-10359
  Scenario: OCP-10359 Group services on overview page
    # Given the master version >= "3.4"
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json" replacing paths:
      | ["metadata"]["name"]           | service-unsecure-1 |
      | ["metadata"]["labels"]["name"] | service-unsecure-1 |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json" replacing paths:
      | ["metadata"]["name"]           | service-unsecure-2 |
      | ["metadata"]["labels"]["name"] | service-unsecure-2 |
    Then the step should succeed
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :group_services web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-1 |
    Then the step should succeed
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-1 |
    Then the step should succeed
    When I perform the :open_create_route_page_from_service_page web console action with:
      | project_name | <%= project.name%>  |
      | service_name | service-unsecure-1  |
    Then the step should succeed
    When I perform the :create_unsecured_route_pointing_to_two_services web console action with:
      | project_name    | <%= project.name%> |
      | route_name      | service-unsecure-1 |
      | service_name    | service-unsecure-1 |
      | first_svc_name  | service-unsecure-1 |
      | second_svc_name | service-unsecure-2 |
      | weight_one      | 1                  |
      | weight_two      | 1                  |
    Then the step should succeed
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_service_group_with_route web console action with:
      | project_name         | <%= project.name %> |
      | primary_service_name | service-unsecure-1  |
      | service_name         | service-unsecure-1  |
    Then the step should succeed
    When I perform the :check_service_group_with_route web console action with:
      | project_name         | <%= project.name %> |
      | primary_service_name | service-unsecure-1  |
      | service_name         | service-unsecure-2  |
    Then the step should succeed
    When I perform the :group_services web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-2 |
    Then the step should succeed
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure |
      | service_name         | service-unsecure |
    Then the step should succeed
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-1 |
    Then the step should succeed
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-2 |
    Then the step should succeed
    When I perform the :remove_service_from_group web console action with:
      | service_name | service-unsecure-1 |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-1 |
    Then the step should fail
    """
    When I perform the :remove_service_from_group web console action with:
      | service_name | service-unsecure-2  |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I perform the :check_service_group_entry web console action with:
      | primary_service_name | service-unsecure   |
      | service_name         | service-unsecure-2 |
    Then the step should fail
    """

