Feature: Check deployments function
  # @author yapei@redhat.com
  # @case_id OCP-12417
  Scenario: Check deployment info on web console
    Given I create a new project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/deployment/deployment1.json |
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

  # @author etrott@redhat.com
  # @case_id OCP-12375
  Scenario: Check ReplicaSet on Overview and ReplicaSet page
    Given the master version >= "3.4"
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/replicaSet/tc536601/replicaset.yaml |
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

