Feature: auto scaling related scenarios

  @admin
  @destructive
  Scenario: setup autoscaling
    Given I switch to cluster admin pseudo user
    Given I enable autoscaling for my cluster
