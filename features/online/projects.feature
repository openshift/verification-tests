Feature: ONLY ONLINE Projects related feature's scripts in this file

  # @author etrott@redhat.com
  # @case_id OCP-12547
  Scenario: OCP-12547 Should use and show the existing projects after the user login
    Given I create a new project
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %>         |
      | token    | <%= user.cached_tokens.first %>  |
      | config   | new_config_file                     |
      | skip_tls_verify | true                         |
    Then the step should succeed
    And the output should contain:
      | You have one project on this server: "<%= project.name %>" |
      | Using project "<%= project.name %>". |
    Then I switch to the second user
    And I run the :login client command with:
      | server   | <%= env.api_endpoint_url %>        |
      | token    | <%= user.cached_tokens.first %> |
      | config   | new_config_file                    |
      | skip_tls_verify | true                         |
    Then the step should succeed
    And the output should contain:
      | You don't have any projects. You can try to create a new project |
    When I run the :config_view client command with:
      | config   | new_config_file |
    Then the step should succeed
    And the output should match:
      | name: .+/.+/<%= user(0, switch: false).name %> |
      | current-context: /.+/<%= user.name %>          |
    Given I create a new project
    When I run the :policy_add_role_to_user client command with:
      | role      | admin                              |
      | user_name | <%= user(0, switch: false).name %> |
      | n         | <%= project.name %>                |
    Then the step should succeed
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %>           |
      | token    | <%= user(0).cached_tokens.first %> |
    Then the step should succeed
    And the output should contain:
      | You have access to the following projects and can switch between them with 'oc project <projectname>': |
      | * <%= @projects[0].name %>                                                                             |
      | <%= @projects[1].name %>                                                                               |

  # @author yasun@redhat.com
  # @case_id OCP-14100
  Scenario: OCP-14100 Should use and show the existing projects after the user login - starter
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %>         |
      | token    | <%= user.cached_tokens.first %>  |
    Then the step should succeed
    And the output should contain:
      | You don't have any projects. You can try to create a new project |
    When I run the :config_view client command
    Then the step should succeed
    And the output should match:
      | current-context: /.+/<%= user.name %>          |
    Given I create a new project
    When I run the :config_view client command
    Then the step should succeed
    And the output should match:
      | name: <%= project.name %>/.+/<%= user.name %>                     |
      | current-context: <%= project.name %>/.+/<%= user.name %>          |

  # @author yasun@redhat.com
  # @case_id OCP-13073
  Scenario: OCP-13073 a new paid-user can not create muti-projects exceed the selected plan limitation
    Given I run the steps <%= user.plan.max_projects %> times:
    """
      Given I create a new project
      Then the step should succeed
    """
    When I create a new project
    Then the output should match:
      | cannot create more than <%= user.plan.max_projects %> project |

