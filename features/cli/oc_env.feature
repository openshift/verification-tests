Feature: oc_env.feature

  # @author xiuwang@redhat.com
  # @case_id OCP-11032
  Scenario: OCP-11032 Set environment variables when creating application using non-DeploymentConfig template
    Given I have a project
    When I run the :new_app client command with:
      | template | cakephp-mysql-example |
      | env | OPCACHE_REVALIDATE_FREQ=3  |
      | env | APPLE1=apple               |
      | env | APPLE2=tesla               |
      | env | APPLE3=linux               |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=cakephp-mysql-example |
    Given I store in the clipboard the pods labeled:
      | name=cakephp-mysql-example |
    When I run the :env client command with:
      | resource | pods/<%= cb.pods[0].name%> |
      | list     | true                       |
    And the output should contain:
      | OPCACHE_REVALIDATE_FREQ=3 |
      | APPLE1=apple              |
      | APPLE2=tesla              |
      | APPLE3=linux              |

