Feature: Online "Notification" related scripts in this file

  # @author bingli@redhat.com
  # @case_id OCP-12870
  Scenario: OCP-12870 Notification UI should correctly display in web console
    Given I have a project
    When I perform the :check_notification_message web console action with:
      | project_name | <%= project.name %> |
      | user_name    | <%= user.name %>    |
    Then the step should succeed

  # @author bingli@redhat.com
  # @case_id OCP-10334
  # @case_id OCP-10341
  Scenario: OCP-10334 Enable/Disable online notification in web console - UI
    Given I have a project
    When I perform the :goto_notification_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :config_deployment_notification web console action with:
      | checkbox_value | true |
    Then the step should succeed
    When I run the :save_notification_config web console action
    Then the step should succeed
    When I run the :get client command with:
      | resource      | configmap                      |
      | resource_name | openshift-online-notifications |
      | template      | {{.data.deployments}}          |
    Then the step should succeed
    And the output should contain "true"
    When I perform the :config_build_notification web console action with:
      | checkbox_value | true |
    Then the step should succeed
    When I run the :save_notification_config web console action
    Then the step should succeed
    When I run the :get client command with:
      | resource      | configmap                      |
      | resource_name | openshift-online-notifications |
      | template      | {{.data.builds}}               |
    Then the step should succeed
    And the output should contain "true"
    When I perform the :config_storage_notification web console action with:
      | checkbox_value | true |
    Then the step should succeed
    When I run the :save_notification_config web console action
    Then the step should succeed
    When I run the :get client command with:
      | resource      | configmap                      |
      | resource_name | openshift-online-notifications |
      | template      | {{.data.storage}}              |
    Then the step should succeed
    And the output should contain "true"
    When I perform the :config_deployment_notification web console action with:
      | checkbox_value | false |
    Then the step should succeed
    When I perform the :config_build_notification web console action with:
      | checkbox_value | false |
    Then the step should succeed
    When I perform the :config_storage_notification web console action with:
      | checkbox_value | false |
    Then the step should succeed
    When I run the :save_notification_config web console action
    Then the step should succeed
    When I run the :get client command with:
      | resource      | configmap                      |
      | resource_name | openshift-online-notifications |
      | template      | {{.data}}                      |
    Then the step should succeed
    And the output should contain:
      | deployments:false |
      | torage:false      |
      | builds:false      |

