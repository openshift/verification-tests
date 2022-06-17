Feature: Check deployments function

  # @author yapei@redhat.com
  # @case_id OCP-10679
  @smoke
  Scenario: OCP-10679 make deployment from web console
    Given I have a project
    # create dc
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/cancel-deployment-gracefully.json |
    Then the step should succeed
    And evaluation of `"hooks"` is stored in the :dc_name clipboard
    When I perform the :wait_latest_deployments_to_deployed web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>   |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :complete

    # manually trigger deploy after deployments is "Deployed"
    When I perform the :manually_deploy web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>   |
    Then the step should succeed

    # sometimes running takes very short time so skip checking disabled deploy button during running, just check running state.
    # cancel deployments
    When I perform the :goto_one_standalone_rc_page web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | <%= cb.dc_name+"-2" %> |
    Then the step should succeed
    # sometimes running takes very short time, just check cancel button, skip to check running status which is already covered by above
    When I run the :cancel_deployment_on_one_deployment_page web action
    Then the step should succeed
    When I perform the :wait_latest_deployments_to_status web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>   |
      | status_name  | Cancelled           |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id OCP-12417
  Scenario: OCP-12417 Check deployment info on web console
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    # check dc detail info
    When I perform the :check_dc_strategy web console action with:
      | project_name | <%= project.name %>   |
      | dc_name      | hooks                 |
      | dc_strategy  | <%= dc.strategy(user:user)["type"] %> |
    Then the step should succeed
    When I perform the :check_dc_manual_cli_trigger web console action with:
      | project_name | <%= project.name %>   |
      | dc_name      | hooks                 |
      | dc_manual_trigger_cli | oc deploy hooks --latest -n <%= project.name %> |
    Then the step should succeed
    When I perform the :check_dc_config_trigger web console action with:
      | project_name | <%= project.name %>   |
      | dc_name      | hooks                 |
      | dc_config_change | Config            |
    Then the step should succeed
    When I perform the :check_dc_selector web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
      | dc_selectors_key | <%= dc.selector(user:user).keys[0] %> |
      | dc_selectors_value | <%= dc.selector(user:user).values[0] %> |
    Then the step should succeed
    When I perform the :check_dc_replicas web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
      | dc_replicas  | <%= dc.replicas(user:user) %>  |
    Then the step should succeed
    # check #1 deployment info
    When I perform the :check_specific_deploy_selector web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
      | dc_number    | 1                      |
      | specific_deployment_selector | deployment=hooks-1 |
    Then the step should succeed
    # check #2 deployment info
    When I perform the :manually_deploy web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
    Then the step should succeed
    When I perform the :wait_latest_deployments_to_deployed web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
    Then the step should succeed
    When I perform the :check_specific_deploy_selector web console action with:
      | project_name | <%= project.name %>    |
      | dc_name      | hooks                  |
      | dc_number    | 2                      |
      | specific_deployment_selector | deployment=hooks-2 |
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id OCP-11198
  Scenario: OCP-11198 View deployments streaming logs
    Given I have a project
    When I run the :new_app client command with:
      | name  | mytest                |
      | image | mysql                 |
      | env   | MYSQL_USER=test       |
      | env   | MYSQL_PASSWORD=redhat |
      | env   | MYSQL_DATABASE=testdb |
    Then the step should succeed

    And I wait until the status of deployment "mytest" becomes :complete
    Given 1 pods become ready with labels:
      | deploymentconfig=mytest |

    When I perform the :check_log_context_on_deployed_deployment_page web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | mytest              |
      | dc_number    | 1                   |
    Then the step should succeed

    When I run the :follow_log web console action
    Then the step should succeed

    When I run the :go_to_top_log web console action
    Then the step should succeed

    When I perform the :open_full_view_log web console action with:
      | log_context | mysql |
    Then the step should succeed

    #Compare the latest deployment log with the running pod log
    When I run the :logs client command with:
      | resource_name    | dc/mytest |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :output clipboard
    When I run the :logs client command with:
      | resource_name    | <%= pod.name %> |
    Then the step should succeed
    And the output should equal "<%= cb.output %>"

  # @author yapei@redhat.com
  # @case_id OCP-10937
  Scenario: OCP-10937 Idled DC handling on web console
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment-with-service.yaml |
    Then the step should succeed
    Given I wait until the status of deployment "hello-openshift" becomes :complete
    When I run the :idle client command with:
      | svc_name | hello-openshift |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "hello-openshift-1"
    # check replicas after idle
    When I perform the :check_dc_replicas web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | hello-openshift     |
      | dc_replicas  | 0                   |
    Then the step should succeed
    When I perform the :check_deployment_idle_text web console action with:
      | project_name      | <%= project.name %> |
      | dc_name           | hello-openshift     |
      | dc_number         | 1                   |
      | previous_replicas | 1                   |
    Then the step should succeed
    When I perform the :check_dc_idle_text_on_overview web console action with:
      | project_name      | <%= project.name %> |
      # parameter dc_name used for v3 only, could be refactored
      | dc_name           | hello-openshift     |
      | resource_type     | deployment          |
      | resource_name     | hello-openshift     |
      | previous_replicas | 1                   |
    Then the step should succeed
    # check_idle_donut_text_on_overview almost duplicate check_dc_idle_text_on_overview for all versions > 3
    When I perform the :check_idle_donut_text_on_overview web console action with:
      | project_name  | <%= project.name %> |
      # parameter dc_name used for v3 only, could be refactored
      | dc_name       | hello-openshift     |
      | resource_type | deployment          |
      | resource_name | hello-openshift     |
    Then the step should succeed
    # check replicas after wake up
    When I perform the :click_wake_up_option_on_overview web console action with:
      | project_name      | <%= project.name %> |
      | dc_name           | hello-openshift     |
      | previous_replicas | 1                   |
    Then the step should succeed
    Given I wait until number of replicas match "1" for replicationController "hello-openshift-1"
    When I perform the :check_dc_replicas web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | hello-openshift     |
      | dc_replicas  | 1                   |
    Then the step should succeed
    When I perform the :check_donut_text_on_overview web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | hello-openshift     |
      | donut_text   | 1                   |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id OCP-11593
  Scenario: OCP-11593 Create,Edit and Delete HPA from the deployment config page
    Given the master version >= "3.3"
    Given I have a project
    When I run the :run client command with:
      | name         | myrun                 |
      | image        | aosqe/hello-openshift |
      | limits       | memory=256Mi          |
    Then the step should succeed
    Given I wait until the status of deployment "myrun" becomes :running
    # create autoscaler
    When I perform the :add_autoscaler_set_max_pod_and_cpu_req_per_from_dc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | max_pods      | 10                  |
      | cpu_req_per   | 60                  |
    Then the step should succeed
    When I perform the :check_autoscaler_min_pods_for_dc web console action with:
      | min_pods      | 1                   |
    Then the step should succeed
    When I perform the :check_autoscaler_max_pods web console action with:
      | max_pods      | 10                  |
    Then the step should succeed
    When I perform the :check_autoscaler_cpu_request_target web console action with:
      | cpu_request_target  | 60%                 |
    Then the step should succeed
    When I perform the :check_autoscaler_min_pods_on_rc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | dc_number     | 1                   |
      | min_pods      | 1                   |
    Then the step should succeed
    When I perform the :check_autoscaler_max_pods_on_rc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | dc_number     | 1                   |
      | max_pods      | 10                  |
    Then the step should succeed
    When I perform the :check_autoscaler_cpu_request_target_on_rc_page web console action with:
      | project_name        | <%= project.name %> |
      | dc_name             | myrun               |
      | dc_number           | 1                   |
      | cpu_request_target  | 60                  |
    Then the step should succeed
    When I perform the :check_dc_link_in_autoscaler_on_rc_page web console action with:
      | project_name        | <%= project.name %> |
      | dc_name             | myrun               |
      | dc_number           | 1                   |
    Then the step should succeed
    # update autoscaler
    When I perform the :update_min_max_cpu_request_for_autoscaler_from_dc_page web console action with:
      | project_name       | <%= project.name %> |
      | dc_name            | myrun               |
      | min_pods           | 2                   |
      | max_pods           | 15                  |
      | cpu_req_per        | 85                  |
    Then the step should succeed
    When I perform the :check_autoscaler_min_pod_on_overview_page web console action with:
      | project_name  | <%= project.name %> |
      | resource_name | myrun               |
      | resource_type | deployment          |
      | min_pods      | 2                   |
    Then the step should succeed
    When I perform the :check_autoscaler_max_pod_on_overview_page web console action with:
      | project_name  | <%= project.name %> |
      | max_pods      | 15                  |
    Then the step should succeed
    When I perform the :manually_deploy web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | myrun               |
    Then the step should succeed
    When I perform the :wait_latest_deployments_to_status web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | myrun               |
      | status_name  | Active              |
    Then the step should succeed
    When I perform the :check_autoscaler_min_pods_on_rc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | dc_number     | 2                   |
      | min_pods      | 2                   |
    Then the step should succeed
    When I perform the :check_autoscaler_max_pods_on_rc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | dc_number     | 2                   |
      | max_pods      | 15                  |
    Then the step should succeed
    When I perform the :check_autoscaler_cpu_request_target_on_rc_page web console action with:
      | project_name        | <%= project.name %> |
      | dc_name             | myrun               |
      | dc_number           | 2                   |
      | cpu_request_target  | 85                  |
    Then the step should succeed
    # delete autoscaler
    When I perform the :delete_autoscaler_from_dc_page web console action with:
      | project_name       | <%= project.name %> |
      | dc_name            | myrun               |
    Then the step should succeed
    When I run the :get client command with:
      | resource  | hpa |
    Then the step should succeed
    And the output should not contain "myrun"

  # @author etrott@redhat.com
  # @case_id OCP-12375
  Scenario: OCP-12375 Check ReplicaSet on Overview and ReplicaSet page
    Given the master version >= "3.4"
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/replicaSet/tc536601/replicaset.yaml |
    Then the step should succeed
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_overview_tile web console action with:
      | resource_type | replica set               |
      | resource_name | frontend                  |
      | image_name    | openshift/hello-openshift |
      | scaled_number | 3                         |
    Then the step should succeed
    And I click the following "a" element:
      | text  | frontend |
    Then the step should succeed
    Given the expression should be true> browser.url =~ /browse\/rs/
    When I perform the :click_to_goto_one_replicaset_page web console action with:
      | project_name         | <%= project.name %> |
      | k8s_replicasets_name | frontend            |
    Then the step should succeed
    When I perform the :check_label web console action with:
      | label_key   | app       |
      | label_value | guestbook |
    Then the step should succeed
    When I perform the :check_label web console action with:
      | label_key   | tier     |
      | label_value | frontend |
    Then the step should succeed
    When I perform the :check_rs_details web console action with:
      | project_name       | <%= project.name %>   |
      | rs_selectors_key   | tier                  |
      | rs_selectors_value | frontend              |
      | replicas           | 3 current / 3 desired |
    Then the step should succeed
    When I perform the :check_pods_number_in_table web console action with:
      | pods_number | 3 |
    Then the step should succeed
    When I run the :scale_up_once web console action
    Then the step should succeed
    When I perform the :check_replicas web console action with:
      | replicas | 4 current / 4 desired |
    Then the step should succeed
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 4 |
    Then the step should succeed
    When I perform the :click_to_goto_one_replicaset_page web console action with:
      | project_name         | <%= project.name %> |
      | k8s_replicasets_name | frontend            |
    Then the step should succeed
    Given I run the steps 2 times:
    """
    When I run the :scale_down_once web console action
    Then the step should succeed
    """
    Given 2 pods become ready with labels:
      | app=guestbook |
    When I perform the :check_replicas web console action with:
      | replicas | 2 current / 2 desired |
    Then the step should succeed
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 2 |
    Then the step should succeed

