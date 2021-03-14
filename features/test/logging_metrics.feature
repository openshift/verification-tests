Feature: test logging and metrics related steps
  @admin
  @destructive
  Scenario: remove OLM installed logging and its related resources
    Given logging service is removed successfully

  @admin
  @destructive
  Scenario: install logging with user parameters
    Given logging operators are installed successfully
    Given I obtain test data file "logging/clusterlogging/example.yaml"
    Given I create clusterlogging instance with:
      | crd_yaml            | example.yaml |
      | remove_logging_pods | true         |
