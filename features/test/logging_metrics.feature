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

  @admin
  Scenario: test logging envs
    Given I switch to cluster admin pseudo user
    Given cluster-logging channel name is stored in the :clo_channel clipboard
    And elasticsearch-operator channel name is stored in the :eo_channel clipboard
    Given elasticsearch-operator catalog source name is stored in the :eo_catsrc clipboard
    Given cluster-logging catalog source name is stored in the :clo_catsrc clipboard
