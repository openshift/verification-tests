Feature: Deploy logging operators via console

  # @author qitang@redhat.com
  # @case_id OCP-22558
  @admin
  @destructive
  Scenario: Deploy cluster-logging operator via web console.
    # clear the logging related resources
    Given logging service is removed successfully
    Given the logging operators are redeployed after scenario
    Given logging channel name is stored in the :logging_channel clipboard
    Given I obtain test data file "logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"
    Given I run the :create admin command with:
      | f | 01_clo_ns.yaml |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given logging service is removed successfully
    Then the step should succeed
    """
    Given "cluster-logging" packagemanifest's catalog source name is stored in the :clo_opsrc clipboard
    Given I switch to the first user
    Given the first user is cluster-admin
    Given I open admin console in a browser
    # subscribe cluster-logging-operator
    When I perform the :goto_operator_subscription_page web action with:
      | package_name     | cluster-logging     |
      | catalog_name     | <%= cb.clo_opsrc %> |
      | target_namespace | openshift-logging   |
    Then the step should succeed
    And I perform the :set_custom_channel_and_subscribe web action with:
      | update_channel    | <%= cb.logging_channel %> |
      | install_mode      | OwnNamespace              |
      | approval_strategy | Automatic                 |
    Given cluster logging operator is ready

  # @author qitang@redhat.com
  # @case_id OCP-24292
  @admin
  @destructive
  Scenario: Deploy elasticsearch-operator via Web Console
    # clear the logging related resources
    Given logging service is removed successfully
    Given the logging operators are redeployed after scenario
    Given logging channel name is stored in the :logging_channel clipboard
    Given "elasticsearch-operator" packagemanifest's catalog source name is stored in the :eo_opsrc clipboard
    Given I switch to the first user
    Given the first user is cluster-admin
    Given admin ensures "elasticsearch-operator" subscriptions is deleted from the "openshift-operators" project after scenario
    Given I open admin console in a browser
    When I perform the :goto_operator_subscription_page web action with:
      | package_name     | elasticsearch-operator |
      | catalog_name     | <%= cb.eo_opsrc %>     |
      | target_namespace | openshift-operators    |
    Then the step should succeed
    When I perform the :set_custom_channel_and_subscribe web action with:
      | update_channel    | <%= cb.logging_channel %> |
      | install_mode      | AllNamespace              |
      | approval_strategy | Automatic                 |
    Then the step should succeed

    Given I use the "openshift-operators" project
    Given I wait for the "elasticsearch-operator" subscriptions to appear
    And evaluation of `subscription("elasticsearch-operator").current_csv` is stored in the :eo_csv clipboard
    Given admin ensures "<%= cb.eo_csv %>" cluster_service_version is deleted from the "openshift-operators" project after scenario
    Given elasticsearch operator is ready in the "openshift-operators" namespace
