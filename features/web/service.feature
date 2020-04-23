Feature: services related feature on web console

  # @author wsun@redhat.com
  # @case_id OCP-10602
  Scenario: Access service pages from web console
    Given I have a project
    # oc process -f file | oc create -f -
    When I process and create "<%= BushSlicer::HOME %>/testdata/routing/tc/tc477695/hello.json"
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
      | f | <%= BushSlicer::HOME %>/testdata/routing/tc/tc477695/new_route.json |
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
