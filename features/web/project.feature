Feature: projects related features via web

  # @author wsun@redhat.com
  # @case_id OCP-12440
  Scenario: OCP-12440 Could list all projects based on the user's authorization on web console
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    Given an 8 characters random string of type :dns is stored into the :project3 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project3 %> |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project1 %>  |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project2 %>  |
    Given I switch to the second user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project3 %> |
    Then the step should fail
    Given I switch to the first user
    When I run the :policy_remove_role_from_user client command with:
      | role | view |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project2 %>  |
    Then the step should succeed
    Given I switch to the second user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project2 %> |
    Then the step should fail
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project3 %> |
    Then the step should fail

  # @author yapei@redhat.com
  # @case_id OCP-10014
  Scenario: OCP-10014 Delete project from web console
    # delete project with project name on projects page
    When I create a project via web with:
      | display_name | testing project one |
      | description  ||
    Then the step should succeed
    When I perform the :type_project_delete_string web console action with:
      | project_name | testing project one      |
      | input_str    | <%= rand_str(7, :dns) %> |
    Then the step should succeed
    When I run the :check_delete_button_for_project_deletion web console action
    Then the step should fail
    When I perform the :delete_project web console action with:
      | project_name | testing project one |
      | input_str    | <%= project.name %> |
    Then the step should succeed
    Given I wait for the resource "project" named "<%= project.name %>" to disappear
    # delete project with project display name
    When I create a project via cli with:
      | display_name | testing project two |
    Then the step should succeed
    When I perform the :cancel_delete_project web console action with:
      | project_name | testing project two |
    Then the step should succeed
    When I perform the :delete_project web console action with:
      | project_name | testing project two |
      | input_str    | testing project two |
    Then the step should succeed
    Given I wait for the resource "project" named "<%= project.name %>" to disappear

