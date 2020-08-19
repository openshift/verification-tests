Feature: some SCC policy related scenarios

  @admin
  @destructive
  Scenario: NFS server
    Given I have a project
    And I have a NFS service in the project
    # one needs to verify scc is deleted upon scenario end

  @admin
  @destructive
  Scenario: restore SCC policy in tear_down
    Given scc policy "restricted" is restored after scenario

  @admin
  Scenario: test scc add and auto remove
    Given I have a project
    Given SCC "privileged" is added to the "system:serviceaccounts:<%= user.name %>:aggregated-logging-fluentd" service account
    And cluster role "cluster-reader" is added to the "system:serviceaccounts:<%= user.name %>:aggregated-logging-fluentd" service account
    And cluster role "oauth-editor" is added to the "system:serviceaccounts:<%= user.name %>:logging-deployer" service account

  @admin
  Scenario: test scc with teardown
    Given I have a project
    Given I create the serviceaccount "test1"
    Given SCC "privileged" is added to the "test1" service account

  @admin
  @upgrade-prepare
  Scenario: test scc without teardown
    Given I have a project
    Given I create the serviceaccount "test2"
    Given SCC "privileged" is added to the "test2" service account without teardown
