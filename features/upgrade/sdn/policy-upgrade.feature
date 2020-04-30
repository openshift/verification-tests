Feature: SDN compoment upgrade testing

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  Scenario: network operator should be available after upgrade - prepare
  # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
  # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
  # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author huirwang@redhat.com
  # @case_id OCP-22707
  @admin
  @upgrade-check
  Scenario: network operator should be available after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-network-operator" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=network-operator |
    # Check network operator version match cluster version
    And the "network" operator version matches the current cluster version
    # Check the operator object has status for Degraded|Progressing|Available|Upgradeable
    And the expression should be true> cluster_operator('network').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('network').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Upgradeable')['status'] == "True"


