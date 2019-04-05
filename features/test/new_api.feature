Feature: test new api methods

  @admin
  Scenario: clusterversion apis
    And evaluation of `cluster_version('version').completed_percentage` is stored in the :upgrade_completion clipboard
    And evaluation of `cluster_version('version').history` is stored in the :history clipboard
    And evaluation of `cluster_version('version').history_matching(key: 'version', value: cluster_version('version').version)` is stored in the :history_match clipboard
    And evaluation of `cluster_version('version').upgrade_completed?(target_version: ENV['UPGRADE_TARGET_VERSION'])` is stored in the :upgrade_completion clipboard
    And evaluation of `cluster_version('version').wait_for_upgrade_completion(target_version: ENV['UPGRADE_TARGET_VERSION'], upgrade_timeout: 10)` is stored in the :upgrade_status clipboard

  @admin
  Scenario: test upgrade by monitoring clusterversion
    Given I upgrade my cluster to:
      | to_image | <%= ENV['UPGRADE_TARGET_VERSION'] %> |
