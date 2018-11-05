Feature: Template service broker related features

  # @author xiuwang@redhat.com
  # @case_id OCP-15486
  Scenario: Deprovision serviceinstance when multiple servicebinding existed 
    Given the master version >= "3.7"
    And I have a project
    When I run the :goto_home_page web console action
    Then the step should succeed
    When I perform the :provision_serviceclass_with_binding_on_homepage web console action with:
      | primary_catagory | Databases          |
      | sub_catagory     | MySQL              |
      | service_item     | MySQL (Ephemeral)  |
    Then the step should succeed
    When I get project serviceinstances as JSON
    And evaluation of `service_instance.name` is stored in the :svcinstancename clipboard
    Given I wait for the "<%= cb.svcinstancename %>" service_instance to become ready up to 180 seconds
    And a pod becomes ready with labels:
      | name=mysql |
    When I get project servicebinding as JSON
    And evaluation of `service_binding.name` is stored in the :svcbindingname clipboard
    When I run the :delete client command with:
      | object_type       | servicebinding           |
      | object_name_or_id | <%= cb.svcbindingname %> |
    Then the step should succeed
    And I wait for the resource "servicebinding" named "<%= cb.svcbindingname %>" to disappear
    When I perform the :create_binding_on_overview_page web console action with:
      | project_name  | <%= project.name %> |
      | resource_name | MySQL               |
    Then the step should succeed
    When I perform the :create_binding_on_overview_page web console action with:
      | project_name  | <%= project.name %> |
      | resource_name | MySQL               |
    Then the step should succeed
    Given I wait for all servicebindings in the project to become ready
    Given I get project secrets
    And the output should match 4 times:
      | mysql.*Opaque | 
    When I perform the :goto_overview_page web console action with:
      | project_name  | <%= project.name %> |
    Then the step should succeed
    When I perform the :delete_serviceinstance_on_overview_page web console action with:
      | resource_name | MySQL (Ephemeral)   |
      | project_name  | <%= project.name %> |
    Then the step should succeed
    And I wait for the resource "serviceinstance" named "<%= cb.svcinstancename %>" to disappear within 300 seconds
    Given I get project secrets
    And the output should not contain "mysql"
    Given I get project templateinstances
    And the output should match:
      | No resources found |

