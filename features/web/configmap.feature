Feature: ConfigMap related features

  # @author xxing@redhat.com
  # @case_id OCP-12006
  Scenario: Edit ConfigMap on web console
    Given the master version >= "3.5"
    Given I have a project
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/configmap/configmap.yaml" replacing paths:
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
