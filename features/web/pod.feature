Feature: Pod related features on web console

  # @author yanpzhan@redhat.com
  # @case_id OCP-11534
  Scenario: OCP-11534 View streaming logs for a running pod
    Given I have a project
    #Create a pod
    And I run the :run client command with:
      | name         | testpod                   |
      | image        | openshift/hello-openshift |
      | generator    | run-pod/v1                |
      | -l           | rc=mytest                 |

    Given the pod named "testpod" becomes ready

    #Go to the pod page
    When I perform the :goto_one_pod_page web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | testpod             |
    Then the step should succeed

    #Check on log tab
    When I perform the :check_log_tab_on_pod_page web console action with:
      | status | Running |
    Then the step should succeed
    #Check log
    When I perform the :check_log_context web console action with:
      | log_context | serving |
    Then the step should succeed
    #View log in new window
    When I perform the :open_full_view_log web console action with:
      | log_context | serving |
    Then the step should succeed

    #Create a pod with 2 containers
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    Given the pod named "doublecontainers" becomes ready

    When I perform the :goto_one_pod_page web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | doublecontainers    |
    Then the step should succeed

    When I perform the :check_log_tab_on_pod_page web console action with:
      | status | Running |
    Then the step should succeed

    #Select one of the containers
    When I perform the :select_a_container web console action with:
      | container_name | hello-openshift-fedora |
    Then the step should succeed

    When I perform the :check_log_context web console action with:
      | log_context | serving |
    Then the step should succeed

    When I perform the :open_full_view_log web console action with:
      | log_context | serving |
    Then the step should succeed

