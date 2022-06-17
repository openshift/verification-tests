Feature: create app on web console related

  # @author hasha@redhat.com
  # @case_id OCP-13718
  Scenario: OCP-13718 Create and view advanced options while creating/selecting project from homepage
    # since it's 3.6 tech preview, no scripts for 3.6
    Given the master version >= "3.6"
    When I run the :goto_home_page web console action
    Then the step should succeed
    When I perform the :select_service_to_order_from_catalog web console action with:
      | primary_catagory | Languages |
      | sub_catagory     | Python    |
      | service_item     | Python    |
    Then the step should succeed
    When I run the :click_next_button web console action
    Then the step should succeed
    # Create first project while creating app
    When I perform the :do_configuration_step_in_wizard web console action with:
      | create_project | true      |
      | project_name   | testpro   |
      | app_name       | pythonapp |
    Then the step should succeed
    When I run the :click_create_button web console action
    Then the step should succeed
    When I perform the :check_successful_result_info_in_wizard web console action with:
      | project_name   | testpro   |
    Then the step should succeed
    When I perform the :check_goto_overview_page_link_in_wizard web console action with:
      | project_name | testpro |
    Then the step should succeed
    When I run the :goto_home_page web console action
    Then the step should succeed
    # add app to existing project
    When I perform the :select_service_to_order_from_catalog web console action with:
      | primary_catagory | Languages |
      | sub_catagory     | Ruby      |
      | service_item     | Ruby      |
    Then the step should succeed
    When I run the :click_next_button web console action
    Then the step should succeed
    When I perform the :do_configuration_step_in_wizard web console action with:
      | create_project | false     |
      | project_name   | testpro   |
      | app_name       | rubyapp   |
    Then the step should succeed
    When I perform the :check_advanced_options_link_in_wizard web console action with:
      | service_item   | Ruby      |
    Then the step should succeed
    When I run the :click_create_button web console action
    Then the step should succeed
    When I run the :check_successful_result_info_on_next_step_page web console action
    Then the step should succeed

