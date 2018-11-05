Feature: logging, metrics, and metering scenarios w/o cleanup

  @admin
  @destructive
  Scenario: test install logging without clean-up
    Given the master version >= "3.5"
    Given I create a project with non-leading digit name
    # test option 'no_cleanup', which means don't register clean-up step in the installation step
    # the service will persists after test exits
    And logging service is installed with ansible using:
      | inventory  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-12377/inventory |
      | no_cleanup | true                                                                                                   |

  @admin
  @destructive
  Scenario: test install hawkular without clean-up
    Given I create a project with non-leading digit name
    Given the master version >= "3.5"
    And metrics service is installed with ansible using:
      | inventory  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-12234/inventory |
      | no_cleanup | true                                                                                                   |

  @admin
  @destructive
  Scenario: test metering install without cleanup
    Given the master version >= "3.10"
    Given I create a project with non-leading digit name
    And I store master major version in the clipboard
    And metering service is installed with ansible using:
      | inventory     | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_install_metering_params |
      | playbook_args | -e openshift_image_tag=v<%= cb.master_version %> -e openshift_release=<%= cb.master_version %>                     |
      | no_cleanup    | true                                                                                                               |

  @admin
  @destructive
  Scenario: test install prometheus without clean-up
    Given I create a project with non-leading digit name
    Given the master version >= "3.5"
    And metrics service is installed with ansible using:
      | inventory  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_inventory_prometheus |
      | no_cleanup | true                                                                                                            |
