Feature: test master config related steps

  Background:
    Given the value with path " " in master config is stored into the :original_cfg clipboard
    Then the expression should be true> Hash === cb.original_cfg
    And I register clean-up steps:
    """
    Given the value with path " " in master config is stored into the :final_cfg clipboard
    Then the expression should be true> cb.original_cfg == cb.final_cfg
    """

  @admin
  @destructive
  Scenario: master config change with multipline parameter
    Given master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: False
    """
    Given the master service is restarted on all master nodes

  @admin
  @destructive
  Scenario: master config will be modified multiple times
    Given master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: False
    """

    Given master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: BadValue
    """

  @admin
  @destructive
  Scenario: the master service will fail to restart and return result
    Given master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: BadValue
    """
    And I try to restart the master service on all master nodes
    Then the step should fail

  @admin
  @destructive
  Scenario: restore master config file before automatic restore
    Given the value with path " " in master config is stored into the :fullcfg clipboard
    And master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: BadValue
    """

    Given the value with path " " in master config is stored into the :changedcfg clipboard
    Then the expression should be true> cb.fullcfg != cb.changedcfg

    When master config is restored from backup
    Then the step should succeed

    Given the value with path " " in master config is stored into the :changedcfg clipboard
    Then the expression should be true> cb.fullcfg == cb.changedcfg

  @admin
  Scenario: get value from master config
    Given the value with path "['dnsConfig']['bindNetwork']" in master config is stored into the :network clipboard
    And the expression should be true> cb.network == "tcp4"
