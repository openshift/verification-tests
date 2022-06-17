Feature: projects related features via homepage

  # @author hasha@redhat.com
  # @case_id OCP-13717
  Scenario: OCP-13717 Manage project in popup panel on home page
    Given the master version >= "3.6"
    Given I have a project
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I perform the :create_project_on_homepage web console action with:
      | project_name | <%= cb.proj_name %>  |
      | display_name | test1_desplay        |
      | description  | test1_description    |
    Then the step should succeed
    # use this step to avoid that button is not clickable related error.
    When I run the :goto_home_page web console action
    Then the step should succeed
    When I run the :check_view_all_link_on_homepage web console action
    Then the step should succeed
    When I run the :check_getting_started_section_missing web console action
    Then the step should succeed
    When I perform the :edit_project_in_kebab_on_homepage web console action with:
      | project_name | <%= project.name %>  |
      | display_name | test2_display        |
      | description  | test2_description    |
    Then the step should succeed
    When I perform the :view_membership_in_kebab_on_homepage web console action with:
      | project_name | <%= project.name %>  |
    Then the step should succeed
    When I run the :check_membership_heading web console action
    Then the step should succeed
    When I run the :goto_home_page web console action
    Then the step should succeed
    When I perform the :delete_project_in_kebab_on_homepage web console action with:
      | project_name | <%= project.name %>  |
      | input_str    | <%= project.name %>  |
    Then the step should succeed
    When I run the :check_getting_started_section_exists web console action
    Then the step should succeed

