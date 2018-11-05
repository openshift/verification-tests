Feature: test metering related steps
  @admin
  @destructive
  Scenario: test metering install
    Given the master version >= "3.10"
    Given I create a project with non-leading digit name
    And I store master major version in the clipboard
    And metering service is installed with ansible using:
      | inventory     | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_install_metering_params |
      | playbook_args | -e openshift_image_tag=v<%= cb.master_version %> -e openshift_release=<%= cb.master_version %>                     |

  # assume we have metering service already installed
  @admin
  @destructive
  Scenario: test report class support
    Given metering service has been installed successfully
    Given I switch to cluster admin pseudo user
    And I use the "openshift-metering" project
    Given I select a random node's host
    Given I get the "node-cpu-capacity" report and store it in the clipboard using:
      | query_type          | node-cpu-capacity |
      | use_existing_report | true              |
    Given I get the "node-cpu-capacity" report and store it in the clipboard using:
      | query_type | node-cpu-capacity |
    Given I get the "node-cpu-capacity" report and store it in the clipboard using:
      | query_type          | node-cpu-capacity |
      | use_existing_report | true              |

