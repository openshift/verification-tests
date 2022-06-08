Feature: creds related steps testing

  @admin
  Scenario: test getting cloudcredentials from cluster
    Given I switch to cluster admin pseudo user
    Given admin obtains the cloudcredentials from cluster and store them to the clipboard

