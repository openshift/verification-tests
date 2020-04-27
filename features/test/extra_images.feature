Feature: test extra images which need to specify the image url

  # @author anli@redhat.com
  # @case_id OCP-29738
  @admin
  Scenario Outline:
    Given I store master major version in the :master_version clipboard
    Given the extra image namespace is stored in the :registry_namespace clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :cur_project clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/features/tierN/testdata/logging/eventrouter/internal_eventrouter.yaml|
      | p    | IMAGE=<%=cb[registry_namespace]%>ose-logging-eventrouter:<%= cb[master_version] %> |
      | p    | NAMESPACE=<%= cb[cur_project] %> |
    Then the step should succeed
    Then a pod becomes ready with labels:
      | component=eventrouter |
