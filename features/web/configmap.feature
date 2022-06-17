Feature: ConfigMap related features

  # @author xxing@redhat.com
  # @case_id OCP-12006
  Scenario: OCP-12006 Edit ConfigMap on web console
    Given the master version >= "3.5"
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/configmap/configmap.yaml" replacing paths:
      | ["data"]["special.who"] | you |
    Then the step should succeed
    When I perform the :goto_configmaps_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :click_to_goto_edit_configmap_page web console action with:
      | config_map_name | special-config |
    Then the step should succeed
    When I perform the :edit_configmap_value web console action with:
      | config_map_key       | special.how    |
      | new_config_map_value | very very very |
    Then the step should succeed
    When I perform the :remove_configmap_item web console action with:
      | config_map_key | special.who |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_key_value_pairs_on_configmap_page web console action with:
      | configmap_key   | special.how    |
      | configmap_value | very very very |
    Then the step should succeed
    When I perform the :check_key_value_pairs_on_configmap_page web console action with:
      | configmap_key   | special.type |
      | configmap_value | charm        |
    Then the step should succeed
    When I perform the :check_missing_key_value_pairs_on_configmap_page web console action with:
      | configmap_key   | special.who |
      | configmap_value | you         |
    Then the step should succeed
    When I run the :click_to_goto_edit_page web console action
    Then the step should succeed
    When I run the :click_to_add_configmap_item web console action
    Then the step should succeed
    When I perform the :add_configmap_key_value_pairs web console action with:
      | item_key   | special.how |
      | item_value | very        |
    Then the step should succeed
    When I run the :check_configmap_error_indicating_duplicate_key web console action
    Then the step should succeed
    When I run the :check_save_button_disabled web console action
    Then the step should succeed
    When I perform the :delete_resources_configmap web console action with:
      | project_name    | <%= project.name %> |
      | config_map_name | special-config      |
    Then the step should succeed
    When I perform the :goto_one_configmap_page web console action with:
      | project_name    | <%= project.name %> |
      | config_map_name | special-config      |
    Then the step should succeed
    When I run the :check_empty_configmap_page_loaded_error web console action
    Then the step should succeed

  # @author etrott@redhat.com
  # @case_id OCP-11052
  Scenario: OCP-11052 Add/Edit env vars from config maps
    Given the master version >= "3.6"
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/ui/application-template-stibuild-without-customize-route.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/hello-deployment-1.yaml   |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/replicaSet/tc536589/replica-set.yaml |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/rc/idle-rc-1.yaml                    |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/configmap/configmap.yaml             |
    Then the step should succeed

    When I perform the :goto_one_dc_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
    Then the step should succeed
    When I perform the :add_env_var_using_configmap_or_secret web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_resource_succesfully_updated_message web console action with:
      | resource | deployment config |
      | name     | database          |
    Then the step should succeed

    When I perform the :goto_one_rc_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | hello-idle          |
    Then the step should succeed
    When I perform the :add_env_var_using_configmap_or_secret web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_resource_updated_message web console action with:
      | resource_name | hello-idle |
    Then the step should succeed

    When I perform the :goto_one_k8s_deployment_environment_tab web console action with:
      | project_name        | <%= project.name %> |
      | k8s_deployment_name | hello-openshift     |
    Then the step should succeed
    When I perform the :add_env_var_using_configmap_or_secret web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_resource_updated_message web console action with:
      | resource_name | hello-openshift |
    Then the step should succeed

    When I perform the :goto_one_k8s_replicaset_environment_tab web console action with:
      | project_name        | <%= project.name %> |
      | k8s_replicaset_name | frontend            |
    Then the step should succeed
    When I perform the :add_env_var_using_configmap_or_secret web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_resource_updated_message web console action with:
      | resource_name | frontend |
    Then the step should succeed

    # Check env vars
    When I perform the :goto_one_dc_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
    Then the step should succeed
    When I perform the :check_configmap_or_secret_env_var web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed

    When I perform the :goto_one_deployment_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
      | dc_number    | 2                   |
    Then the step should succeed
    When I perform the :check_environment_variable web console action with:
      | env_var_key   | my_configmap                                            |
      | env_var_value | Set to the key special.how in config map special-config |
    Then the step should succeed

    When I perform the :goto_one_rc_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | hello-idle          |
    Then the step should succeed
    When I perform the :check_configmap_or_secret_env_var web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed

    When I perform the :goto_one_k8s_deployment_environment_tab web console action with:
      | project_name        | <%= project.name %> |
      | k8s_deployment_name | hello-openshift     |
    Then the step should succeed
    When I perform the :check_configmap_or_secret_env_var web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed

    When I perform the :goto_one_k8s_replicaset_environment_tab web console action with:
      | project_name        | <%= project.name %> |
      | k8s_replicaset_name | frontend            |
    Then the step should succeed
    When I perform the :check_configmap_or_secret_env_var web console action with:
      | env_var_key   | my_configmap   |
      | resource_name | special-config |
      | resource_key  | special.how    |
    Then the step should succeed

