Feature: test extra images which need to specify the image url
  # @author anli@redhat.com
  @admin
  Scenario Outline:
    Given I switch to cluster admin pseudo user
    Given I store master major version in the :master_version clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :cur_project clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/features/tierN/testdata/logging/eventrouter/internal_eventrouter.yaml|
      | p    | IMAGE=registry.stage.redhat.io/openshift4/ose-logging-eventrouter:<%= cb[master_version] %> |
      | p    | NAMESPACE=<%= cb[cur_project] %> |
    Then the step should succeed
    Then a pod becomes ready with labels:
      | component=eventrouter |
