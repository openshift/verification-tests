Feature: oc_login.feature

  # @author xiaocwan@redhat.com
  # @case_id OCP-11888
  @smoke
  Scenario: OCP-11888 User can login with the new generated token via web page for oc
    Given I log the message> this scenario can pass only when user accounts have a known password
    When I perform the :request_token_with_password web console action with:
      | url    | <%= env.api_endpoint_url %>/oauth/token/request |
      | username  | <%= user(0, switch: false).name %>    |
      | password |  <%= user(0, switch: false).password %>   |
      | _nologin | |
    Then the step should succeed
    When I get the content of the "element" web element:
      | xpath | //code |
    And I run the :login client command with:
      | server   | <%= env.api_endpoint_url %> |
      | token | <%= @result[:response].split(">")[1].split("<")[0] %>   |
    Then the step should succeed

