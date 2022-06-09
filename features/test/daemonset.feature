Feature: test daemonset methods

  @admin
  Scenario: Test daemonset support in the framework
    Given I have a project
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create admin command with:
      | f | daemonset.yaml |
      | n | <%= project.name %>                                                                      |
    Then the step should succeed
    And "hello-daemonset" daemonset becomes ready in the "<%= project.name %>" project
