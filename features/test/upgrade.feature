Feature: basic verification for upgrade testing

  # note that upuser1 and 2 need to be defined for the environement
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: prepare 2 users
    Given the user has all owned resources cleaned
    When I run the :new_project client command with:
      | project_name | upgrade-project-1 |
    Then the step should succeed

    Given the second user has all owned resources cleaned
    When I run the :new_project client command with:
      | project_name | upgrade-project-2 |
    Then the step should succeed

  @upgrade-check
  @users=upuser1,upuser2
  Scenario: check the 2 users
    Given I use the "upgrade-project-1" project
    And I switch to the second user
    And I use the "upgrade-project-2" project
