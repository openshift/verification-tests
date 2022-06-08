Feature: test metering related steps

  @admin
  @destructive
  Scenario: test metering install
    Given the master version >= "3.10"
    Given I create a project with non-leading digit name
    And I store master major version in the clipboard
    Given I obtain test data file "logging_metrics/default_install_metering_params"
    And metering service is installed with ansible using:
      | inventory     | default_install_metering_params |
      | playbook_args | -e openshift_image_tag=v<%= cb.master_version %> -e openshift_release=<%= cb.master_version %>                     |

  # assume we have metering service already installed
  @admin
  @destructive
  Scenario: test report class support
    Given metering service has been installed successfully
    Given I switch to cluster admin pseudo user
    And I use the "<%= cb.metering_namespace.name %>" project
    Given I select a random node's host
    Given I get the "node-cpu-capacity" report and store it in the clipboard using:
      | run_immediately | true               |
      | query_type      | node-cpu-capacity   |
    Given I get the "node-memory-capacity-test" report and store it in the clipboard using:
      | query_type      | node-memory-capacity                              |
      | run_immediately | false                                             |
      | schedule        | { period: hourly, hourly: {minute: 0, second: 0}} |
      | start_time      | <%= Time.now.utc.strftime('%FT%TZ') %>            |

  @admin
  @destructive
  Scenario: test create app to support metering reports
    Given I have a project
    And evaluation of `project.name` is stored in the :org_proj_name clipboard
    And I setup an app to test metering reports
    Given metering service has been installed successfully
    And I use the "<%= cb.metering_namespace.name %>" project
    Given I get the "persistentvolumeclaim-request" report and store it in the clipboard using:
      | query_type | persistentvolumeclaim-request |
    Given I wait until "persistentvolumeclaim-request" report for "<%= cb.org_proj_name %>" namespace to be available

  @admin
  @destructive
  Scenario: test external access of metering query
    Given metering service has been installed successfully
    And I use the "<%= cb.metering_namespace.name %>" project
    Given I get the "node-cpu-capacity" report and store it in the :res_json clipboard using:
      | query_type | node-cpu-capacity |

  @admin
  @destructive
  Scenario: install metering using openshift-install.sh
    Given I have a project
    And I have a git client pod in the project
    Given metering service has been installed successfully using shell script
    Given metering service is uninstalled using shell script
    And I switch to the first user
    Given metering service has been installed successfully using ansible

  @admin
  Scenario: test report generation step
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-metering" project

    Then I generate a metering report with:
      | metadata_name | test                     |
      | query_type    | namespace-memory-request |

  @admin
  Scenario: test enable metering route
    Given I switch to cluster admin pseudo user
    And I use the "openshift-metering" project
    And evaluation of `"openshift-metering"` is stored in the :metering_namespace clipboard
    And I enable route for metering service


