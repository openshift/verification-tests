Feature: fluentd related tests

  # @author pruan@redhat.com
  # @case_id OCP-10995
  @admin
  @destructive
  Scenario: OCP-10995 Check fluentd changes for common data model and index naming
    Given I create a project with non-leading digit name
    And evaluation of `project` is stored in the :org_project clipboard
    When I run the :new_app client command with:
      | app_repo | httpd-example |
    Then the step should succeed
    And logging service is installed in the system
    When I wait 600 seconds for the "project.<%= cb.org_project.name %>" index to appear in the ES pod with labels "component=es"
    And the expression should be true> cb.proj_index_regex = /project.#{cb.org_project.name}.#{cb.org_project.uid}.(\d{4}).(\d{2}).(\d{2})/
    And the expression should be true> cb.op_index_regex = /.operations.(\d{4}).(\d{2}).(\d{2})/
    Given I log the message> <%= cb.index_data['index'] %>
    And the expression should be true> cb.proj_index_regex.match(cb.index_data['index'])
    And I wait for the ".operations" index to appear in the ES pod
    Given I log the message> <%= cb.index_data['index'] %>
    And the expression should be true> cb.op_index_regex.match(cb.index_data['index'])

