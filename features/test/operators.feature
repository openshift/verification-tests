Feature: operators related

  @admin
  Scenario: test logging support apis
    Given I switch to cluster admin pseudo user
    Given all clusteroperators reached version "<%= ENV['UPGRADE_TARGET_VERSION'] %>" successfully

  @admin
  Scenario: test checking all clusteroperators
    Given I wait for all clusteroperators to be ready

  @admin
  Scenario: test print pods and nodes info unless success
    Given operator "authentication" becomes available/non-progressing/non-degraded within 30 seconds
    Given operator "authentication" becomes available/progressing/non-degraded within 30 seconds
