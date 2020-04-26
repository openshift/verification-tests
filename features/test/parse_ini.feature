Feature: test ini files
  @admin
  Scenario: parse ini formated file
    Given I parse the INI file "<%= BushSlicer::HOME %>/testdata/logging_metrics/default_inventory_prometheus"
    And I select a random node's host
    Given label "region=infra" is added to the node
    And I pry
