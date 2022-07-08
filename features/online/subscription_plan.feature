Feature: ONLY ONLINE subscription plan related scripts in this file

  # @author xiaocwan@redhat.com
  Scenario Outline: Plan add-on can be added under the limit
    Given I open accountant console in a browser
    When I perform the :goto_resource_settings_page web action with:
      | resource | <resource> |
    Then the step should succeed
    When I perform the :set_max_value_by_exceed web action with:
      | resource           | <resource>           |
      | exceed_amount      | <exceed_amount>      |
      | cur_amount         | <current>            |
      | current            | <current> GiB        |
      | resource_page_name | <resource_page_name> |
      | previous           | <previous>           |
      | total              | <total>              |
    Then the step should succeed
    And I register clean-up steps:
    """
    I perform the :goto_resource_settings_page web action with:
      | resource | <resource> |
    the step should succeed
    I perform the :set_resource_amount_by_input_and_update web action with:
      | resource | <resource> |
      | amount   | 0          |
    the step should succeed
    """
    Given I have a project
    Given the "<acrq_name>" applied_cluster_resource_quota is stored in the clipboard
    Then the expression should be true> cb.acrq.hard_quota(cached: false).<type>_raw  == "<total>Gi"

    Examples:
      | case_id   | resource           | exceed_amount | current | total | acrq_name  | resource_page_name | previous | type             |
      | OCP-10426 | storage            | 149           | 148     | 150   | noncompute | storage            | 0        | storage_requests | # @case_id OCP-10426
      | OCP-10427 | memory             | 47            | 46      | 48    | compute    | memory             | 0        | memory_limit     | # @case_id OCP-10427
      | OCP-13347 | terminating_memory | 19            | 18      | 20    | timebound  | terminating memory | 0        | memory_limit     | # @case_id OCP-13347

  # @author yuwei@redhat.com
  Scenario Outline: Check elements on Manage add-on Page - UI
    Given I open accountant console in a browser
    When I perform the :goto_resource_settings_page web action with:
      | resource | <resource> |
    Then the step should succeed
    When I perform the :check_title_on_manage_resoure_page web action with:
      | resource_title | <resource_title> |
    Then the step should succeed
    When I perform the :check_addon_slider_of_resource web action with:
      | resource  | <resource>  |
      | max_value | <max_value> |
    Then the step should succeed
    When I perform the :check_addon_input_field_of_resource web action with:
      | resource  | <resource>  |
      | max_value | <max_value> |
    Then the step should succeed
    When I run the :check_update_subscription_button web action
    Then the step should succeed
    When I run the :check_keep_current_plan web action
    Then the step should succeed

    Examples: Check elements on Manage add-on Page - UI
    | case_id   | resource           | resource_title     | max_value |
    | OCP-12753 | memory             | memory             | 46        | # @case_id OCP-12753
    | OCP-14276 | terminating_memory | terminating memory | 18        | # @case_id OCP-14276
    | OCP-14893 | storage            | persistent storage | 148       | # @case_id OCP-14893

