Feature: check page info related
  # @author yapei@redhat.com
  # @case_id OCP-12625
  Scenario: Check home page to list user projects
    Given I login via web console
    When I run the :check_instructions_on_home_page web console action
    Then the step should succeed
    Given an 8 character random string of type :dns is stored into the :prj_name clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.prj_name %> |
    Then the step should succeed
    When I run the :check_project_list web console action
    Then the step should succeed
    When I get the html of the web page
    Then the output should contain:
      | <%= cb.prj_name %> |
