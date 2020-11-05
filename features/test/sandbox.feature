Feature: sandbox
  @admin
  @destructive
  Scenario: test step
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-metering" project
    Given I ensure "metering-ocp-sub" subscription is deleted
    Given I ensure "metering-ocp-og" subscription is deleted
    Given I ensure "openshift-metering" meteringconfig is deleted
    #And I remove all custom_resource_definition in the project with labels:
    #  | operators.coreos.com/metering-ocp.openshift-metering= |
    And I pry
