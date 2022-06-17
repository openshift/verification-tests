Feature: memberships related features via web

  # @author etrott@redhat.com
  # @case_id OCP-11843
  Scenario: OCP-11843 Manage project membership about users
    Given the master version >= "3.4"
    Given I have a project
    When I perform the :check_entry_content_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | name         | <%= user.name %>    |
      | role         | admin               |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | count        | 1                   |
    Then the step should succeed
    When I perform the :add_role_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | name         | test_user           |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_entry_content_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | name         | test_user           |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | count        | 2                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding        |
    Then the output should contain:
      | basic-user|
      | test_user |
    When I perform the :delete_role_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | name         | test_user           |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Users               |
      | count        | 1                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding |
    Then the output should not contain:
      | basic-user |
      | test_user  |
    When I perform the :check_entry_content_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %>  |
      | tab_name     | Service Accounts     |
      | namespace    | <%= project.name %>  |
      | name         | builder              |
      | role         | system:image-builder |
    Then the step should succeed
    When I perform the :check_entry_content_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | <%= project.name %> |
      | name         | deployer            |
      | role         | system:deployer     |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | count        | 2                   |
    Then the step should succeed
    When I perform the :add_sa_role_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | <%= project.name %> |
      | name         | test.sa             |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_entry_content_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | <%= project.name %> |
      | name         | test.sa             |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | count        | 3                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding |
    Then the output should contain:
      | basic-user |
      | test.sa    |
    When I perform the :delete_role_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | <%= project.name %> |
      | name         | test.sa             |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | count        | 2                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding |
    Then the output should not contain:
      | basic-user |
      | test.sa    |
    When I perform the :add_role_on_membership_with_typed_namespace web console action with:
      | project_name  | <%= project.name %> |
      | tab_name      | Service Accounts    |
      | old_namespace | <%= project.name %> |
      | namespace     | default             |
      | name          | test.sa             |
      | role          | basic-user          |
    Then the step should succeed
    When I perform the :check_entry_content_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | default             |
      | name         | test.sa             |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | count        | 3                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding|
    Then the output should contain:
      | basic-user |
      | test.sa    |
    When I perform the :delete_role_on_membership_with_namespace web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | namespace    | default             |
      | name         | test.sa             |
      | role         | basic-user          |
    Then the step should succeed
    When I perform the :check_tab_count_on_membership web console action with:
      | project_name | <%= project.name %> |
      | tab_name     | Service Accounts    |
      | count        | 2                   |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | rolebinding |
    Then the output should not contain:
      | basic-user |
      | test.sa    |

