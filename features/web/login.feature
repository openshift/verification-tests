Feature: login related scenario

  # @author wjiang@redhat.com
  # @case_id OCP-12239
  @smoke
  Scenario: OCP-12239 login and logout via web
    Given I login via web console
    Given I run the :logout web console action
    Then the step should succeed
    When I perform the :access_overview_page_after_logout web console action with:
      | project_name | <%= rand_str(2, :dns) %> |
    Then the step should succeed

  # @author xxing@redhat.com
  # @case_id OCP-9771
  Scenario: OCP-9771 User could not access pages directly without login first
    Given I have a project
    # Disable default login
    When I perform the :new_project_navigate web console action with:
      | _nologin | true |
    Then the step should succeed
    Given I wait for the title of the web browser to match "(Login|Sign\s+in|SSO|Log In)"
    When I access the "/console/project/<%= project.name %>/create" path in the web console
    Given I wait for the title of the web browser to match "(Login|Sign\s+in|SSO|Log In)"
    When I access the "/console/project/<%= project.name %>/overview" path in the web console
    Given I wait for the title of the web browser to match "(Login|Sign\s+in|SSO|Log In)"

  # @author xxing@redhat.com
  # @case_id OCP-12189
  Scenario: OCP-12189 The page should redirect to login page when access session protected pages after session expired
    When I create a new project via web
    Then the step should succeed
    #make token expired
    And the expression should be true> browser.execute_script("return window.localStorage['LocalStorageUserStore.token']='<%= rand_str(32, :dns) %>';")
    When I access the "/console/project/<%= project.name %>/overview" path in the web console
    Given I wait for the title of the web browser to match "(Login|Sign\s+in|SSO|Log In)"

