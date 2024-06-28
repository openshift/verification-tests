Feature: test new api methods

  @admin
  Scenario: clusterversion apis
    And evaluation of `cluster_version('version').completed_percentage` is stored in the :upgrade_completion clipboard
    And evaluation of `cluster_version('version').history` is stored in the :history clipboard
    And evaluation of `cluster_version('version').history_matching(key: 'version', value: cluster_version('version').version)` is stored in the :history_match clipboard
    And evaluation of `cluster_version('version').upgrade_completed?(version: ENV['UPGRADE_TARGET_VERSION'])` is stored in the :upgrade_completion clipboard
    And evaluation of `cluster_version('version').wait_for_upgrade_completion(version: ENV['UPGRADE_TARGET_VERSION'], timeout: 10)` is stored in the :upgrade_status clipboard

  @admin
  @destructive
  Scenario: test upgrade by monitoring clusterversion
    Given I upgrade my cluster to:
      | to_image               | <%= ENV['UPGRADE_TARGET_VERSION'] %> |
      | allow_explicit_upgrade | true                                 |

  @admin
  @destructive
  Scenario: test logging support apis
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    And I wait for clusterlogging to be functional in the project

  @admin
  Scenario: test new route apis
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    And evaluation of `route('prometheus-k8s').spec.host` is stored in the clipboard

  @admin
  Scenario: check cluster_version capabilities
    And the expression should be true> cluster_version('version').capability_is_enabled?(capability: 'ImageRegistry')
    And the expression should be true> cluster_version('version').capability_is_enabled?(capability: 'MachineAPI')
