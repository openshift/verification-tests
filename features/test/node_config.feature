Feature: test node config related steps

  Background:
    Given I select a random node's host
    And the value with path " " in node config is stored into the :original_cfg clipboard
    Then the expression should be true> Hash === cb.original_cfg
    And I register clean-up steps:
    """
    Given the value with path " " in node config is stored into the :final_cfg clipboard
    Then the expression should be true> cb.original_cfg == cb.final_cfg
    """

  @admin
  @destructive
  Scenario: node config change with multipline parameter
    Given config of all nodes is merged with the following hash:
    """
    iptablesSyncPeriod: "35s"
    """
    And the node service is restarted on all nodes

  @admin
  @destructive
  Scenario: node config will be modified multiple times
    Given config of all nodes is merged with the following hash:
    """
    iptablesSyncPeriod: "35s"
    """

    Given config of all nodes is merged with the following hash:
    """
    iptablesSyncPeriod: "40s"
    """

  @admin
  @destructive
  Scenario: the node service will fail to restart and return result
    Given config of all schedulable nodes is merged with the following hash:
    """
    apiVersion: BadValue
    """
    And I try to restart the node service on all schedulable nodes
    Then the step should fail

  @admin
  @destructive
  Scenario: restore node config file before automatic restore
    Given config of all nodes is merged with the following hash:
    """
    iptablesSyncPeriod: "35s"
    """
    And the value with path " " in node config is stored into the :changedcfg clipboard
    Then the expression should be true> cb.original_cfg != cb.changedcfg
    Given all nodes config is restored
    And the value with path " " in node config is stored into the :restoredcfg clipboard
    Then the expression should be true> cb.original_cfg == cb.restoredcfg

  @admin
  Scenario: get value from node config
    Given the value with path "['networkConfig']['mtu']" in node config is stored into the :mtu clipboard
    And the expression should be true> Integer === cb.mtu
