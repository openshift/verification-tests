Feature: example kata container scenarios
  @admin
  @destructive
  @upgrade-prepare
  Scenario: kata container operator installation
    Given the master version >= "4.6"
    Given kata container has been installed successfully in the "kata-operator" project
    And I verify kata container runtime is installed into the a worker node

  @admin
  @destructive
  @upgrade-prepare
  Scenario: test delete kata installation
    Given the master version >= "4.6"
    Given I switch to cluster admin pseudo user
    And I remove kata operator from "kata-operator" namespace

  Scenario: test get channel
    Given I extract the channel information from subscription and save it to the :channel clipboard
