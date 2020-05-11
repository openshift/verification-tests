Feature: check settings page on web console
  # @author hasha@redhat.com
  # @case_id OCP-16826
  Scenario: User could set console home page
    Given the master version >= "3.9"

    # not able to set homepage as project overview when user has no project
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview |
    Then the step should fail
    When I run the :click_cancel_button web console action
    Then the step should succeed

    # set homepage to project overview when only one project
    Given I create a new project
    Then evaluation of `project.name` is stored in the :project1 clipboard
    When I access the "/console" path in the web console
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | Get started with your project. |
    Then the step should succeed

    # set homepage as one project overview when user has more than one project
    Given I create a new project
    Then evaluation of `project.name` is stored in the :project2 clipboard
    When I access the "/console" path in the web console
    When I perform the :set_home_page web console action with:
      | prefered_homepage | project-overview   |
      | project_name      | <%= cb.project2 %> |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | <%= cb.project2 %> |
    Then the step should succeed

    # should give warning when visiting /console after project deleted
    When I delete the project
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | no longer exists or you do not have access to it.|
    Then the step should succeed

    # set home page back to 1st project overview, add view role to 2nd user, check 2nd user could see previous home page setting
    When I run the :click_set_homepage web console action
    Then the step should succeed
    When I perform the :set_homepage_in_modal web console action with:
      | prefered_homepage | project-overview |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | view                               |
      | user_name | <%= user(1,switch: false).name %>  |
      | n         | <%= cb.project1 %>                 |
    Then the step should succeed
    Given I logout via web console
    Given the second user is using same web console browser as first
    Given I switch to the second user
    Given I login via web console
    When I perform the :check_page_contain_text web action with:
      | text | <%= cb.project1 %> |
    Then the step should succeed

    # remove view role form 2nd user and visit /console, not able to view
    Given I switch to the first user
    When I run the :policy_remove_role_from_user client command with:
      | role      | view                               |
      | user_name | <%= user(1,switch: false).name %>  |
      | n         |  <%= cb.project1 %>                |
    Then the step should succeed
    When I access the "/console" path in the web console
    When I perform the :check_page_contain_text web console action with:
      | text | no longer exists or you do not have access to it.|
    Then the step should succeed

