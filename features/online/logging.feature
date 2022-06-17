Feature: online logging tests

  # @author pruan@redhat.com
  # @case_id OCP-10767
  Scenario: OCP-10767 Logout kibana web console
    Given I create a project with non-leading digit name
    Given I login to kibana logging web console
    When I perform the :logout_kibana web action with:
      | kibana_url | <%= cb.logging_console_url %> |
    Then the step should succeed
    And I access the "<%= cb.logging_console_url %>" url in the web browser
    Given I wait for the title of the web browser to match "(Login|Sign\s+in|SSO|Log In)"

