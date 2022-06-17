Feature: test daemonset methods

  @admin
  Scenario: Test daemonset support in the framework
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/daemon/daemonset.yaml |
      | n | <%= project.name %>                                                                      |
    Then the step should succeed
    And "hello-daemonset" daemonset becomes ready in the "<%= project.name %>" project
