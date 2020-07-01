Feature: Some basic project related tests

  Scenario: project methods
    When I have a project
    Then I delete the project
    Given I create 10 new projects

  Scenario: test special project step
    Given I create a project with non-leading digit name
    And the expression should be true> project.name.match(/^(\d)/).nil?

  Scenario: test project methods
    Given I have a project
    And evaluation of `project.uid` is stored in the :proj_uid clipboard
    And evaluation of `project.uid_range` is stored in the :proj_uid_range clipboard
    And evaluation of `project.mcs` is stored in the :proj_mcs clipboard
    And evaluation of `project.supplemental_groups` is stored in the :proj_sg clipboard
