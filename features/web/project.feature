Feature: projects related features via web

  # @author wsun@redhat.com
  # @case_id OCP-12440
  Scenario: Could list all projects based on the user's authorization on web console
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
