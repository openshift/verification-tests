@clusterlogging
Feature: permission related test

  # @author qitang@redhat.com
  # @case_id OCP-25364
  @admin
  @destructive
  @commonlogging
  Scenario: [BZ1446217] View the project mapping index as different roles
    Given I switch to the first user
    Given I create a project with non-leading digit name
    And evaluation of `project` is stored in the :project clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/testdata/logging/loggen/container_json_log_template.json |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    And I wait for the "project.<%= cb.project.name %>.<%= cb.project.uid %>" index to appear in the ES pod with labels "es-node-master=true"
    # the project is created by the first user, so no need to grant permission for the first user
    # Give user2 edit role
    When I run the :policy_add_role_to_user client command with:
      | role             | edit                               |
      | user_name        | <%= user(1, switch: false).name %> |
      | rolebinding_name | edit                               |
      | n                | <%= cb.project.name %>             |
    Then the step should succeed
    # Give user3 view role
    When I run the :policy_add_role_to_user client command with:
      | role             | view                               |
      | user_name        | <%= user(2, switch: false).name %> |
      | rolebinding_name | view                               |
      | n                | <%= cb.project.name %>             |
    Then the step should succeed
    Given evaluation of `%w[first second third]` is stored in the :users clipboard
    Given I repeat the following steps for each :user in cb.users:
    """
    Given I switch to the #{cb.user} user
    And evaluation of `user.cached_tokens.first` is stored in the :user_token clipboard
    Given I switch to cluster admin pseudo user
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | project.<%= cb.project.name %>.*/_count |
      | op           | GET                                     |
      | token        | #{cb.user_token}                        |
    Then the step should succeed
    Then the expression should be true> @result[:parsed]['count'] > 0
    """
