Feature: test daemonset methods
  @admin
  Scenario: Test daemonset support in the framework
    Given I have a project
    When I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/daemon/daemonset.yaml |
      | n | <%= project.name %>                                                                      |
    Then the step should succeed
    And "hello-daemonset" daemonset becomes ready in the "<%= project.name %>" project
