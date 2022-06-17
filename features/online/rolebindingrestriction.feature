Feature: rolebindingrestriction.feature

  # @author zhaliu@redhat.com
  Scenario Outline: Restrict making a role binding to user except project admin by default
    Given I have a project
    When I run the :get client command with:
      | resource      | rolebindingrestriction   |
      | resource_name | match-project-admin-user |
      | o             | json                     |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["spec"]["userrestriction"]["users"].include? user.name

    When I run the :policy_add_role_to_user client command with:
      | role      | edit       |
      | user_name | <username> |
    Then the step should <result>
    And the output should match:
      | <output> |
    Examples:
      | username         | output                                               | result  |
      | userA            | .*"edit".*forbidden:.*"userA".*"<%= project.name %>" | fail    | # @case_id OCP-13120
      | <%= user.name %> | role "edit" added: "<%= user.name %>"                | succeed | # @case_id OCP-13146

  # @author zhaliu@redhat.com
  Scenario Outline: Restrict making a role binding to service accounts except in own project by default
    Given I have a project
    When I run the :get client command with:
      | resource      | rolebindingrestriction     |
      | resource_name | match-own-service-accounts |
      | o             | json                       |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["spec"]["serviceaccountrestriction"]["namespaces"].include? project.name

    When I run the :policy_add_role_to_user client command with:
      | role              | view             |
      | serviceaccountraw | <serviceaccount> |
    Then the step should <result>
    And the output should match:
      | <output> |
    Examples:
      | serviceaccount                                     | output                                                    | result  |
      | system:serviceaccount:openshift:deployer           | .*"view".*forbidden:.*".*deployer".*"<%= project.name %>" | fail    | # @case_id OCP-13805
      | system:serviceaccount:<%= project.name %>:deployer | role "view" added: ".*deployer"                           | succeed | # @case_id OCP-13115

  # @author zhaliu@redhat.com
  Scenario Outline: Restrict making a role binding to groups except system group built in own project by default
    Given I have a project
    When I run the :get client command with:
      | resource      | rolebindingrestriction          |
      | resource_name | match-own-service-account-group |
      | o             | json                            |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["spec"]["grouprestriction"]["groups"].include? "system:serviceaccounts:#{project.name}"

    When I run the :policy_add_role_to_group client command with:
      | role       | view         |
      | group_name | <group_name> |
    Then the step should <result>
    And the output should match:
      | <output> |
    # @case_id OCP-13121
    Examples: Restrict making a role binding to the groups
      | group_name                       | output                                                                          | result |
      | groupA                           | .*"view".*forbidden:.*"groupA".*"<%= project.name %>"                           | fail   |
      | system:serviceaccounts           | .*"view".*forbidden:.*"system:serviceaccounts".*"<%= project.name %>"           | fail   |
      | system:serviceaccounts:openshift | .*"view".*forbidden:.*"system:serviceaccounts:openshift".*"<%= project.name %>" | fail   |
    # @case_id OCP-13795
    Examples: Allow to make a role binding to the system service account group
      | group_name                                 | output                                                          | result  |
      | system:serviceaccounts:<%= project.name %> | role "view" added: "system:serviceaccounts:<%= project.name %>" | succeed |

  # @author zhaliu@redhat.com
  # @case_id OCP-13798
  Scenario: OCP-13798 After the project is deleted the rolebindingrestriction will be deleted too
    Given I have a project
    And evaluation of `project.name` is stored in the :project_name clipboard
    When I run the :get client command with:
      | resource | rolebindingrestriction |
    Then the step should succeed
    And the output should contain:
      | match-project-admin-user        |
      | match-own-service-accounts      |
      | match-own-service-account-group |
    When I run the :delete client command with:
      | object_type       | project                |
      | object_name_or_id | <%= cb.project_name %> |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :new_project client command with:
      | project_name | <%= cb.project_name %> |
    Then the step should succeed
    """
    When I run the :get client command with:
      | resource | rolebindingrestriction |
    Then the step should succeed
    And the output should contain:
      | match-project-admin-user        |
      | match-own-service-accounts      |
      | match-own-service-account-group |

