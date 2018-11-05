Feature: console test

  Scenario: new project via console test
    When I perform the :new_project web console action with:
      |project_name|<%= rand_str(5, :dns) %>|
      |description| sadfsdf is |
    Then the step should succeed
    When I create a new project via web
    Then the step should succeed
    When I create a new project via web
    Then the step should succeed

  Scenario: smart login web console
    Given I login via web console

  Scenario: switch-to-window test
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Then the step should succeed
    When I perform the :goto_routes_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I click the following "a" element:
      | target | _blank |
    Then the step should succeed
    When I perform the :check_common_elements web console action in ":url=>example\.com" window with:
      | what | More information |
    Then the step should succeed

  Scenario: switch-to-window test for web rules
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Then the step should succeed
    When I perform the :goto_routes_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :switch_window_demo web console action with:
      | what | More information |
    Then the step should succeed

  Scenario: navigate to arbitrary web url
    Given I login via web console
    When I access the "https://github.com" url in the web browser
