Feature: resouces related scenarios

  # @author xxia@redhat.com
  # @case_id OCP-11882
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Return description of resources with cli describe
    Given I have a project
    And I create a new application with:
      | file     | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    And I wait until the status of deployment "database" becomes :running
    When I run the :describe client command with:
      | resource     | svc           |
      | name         | database      |
    Then the step should succeed
    And the output should match:
      | Name:\\s+database            |
      | Selector:\\s+name=database   |
    When I run the :get client command with:
      | resource      | svc      |
      | resource_name | database |
      | o             | yaml     |
    Then the step should succeed
    Given I save the output to file> svc.yaml
    When I run the :describe client command with:
      | resource     | :false        |
      | name         | :false        |
      | f            | svc.yaml      |
    Then the step should succeed
    And the output should match:
      | Name:\\s+database            |
    When I run the :describe client command with:
      | resource     | svc           |
      | name         | :false        |
      | l            | app           |
    Then the step should succeed
    And the output should match:
      | Name:\\s+database            |
    When I run the :describe client command with:
      | resource     | svc           |
      | name         | databa        |
    Then the step should succeed
    And the output should match:
      | Name:\\s+database            |
    # The following steps shorten the multiple steps of the TCMS case
    When I run the :describe client command with:
      | resource     | :false        |
      | name         | rc/database-1                     |
      | name         | is/origin-ruby-sample             |
      | name         | dc/frontend                       |
    Then the step should succeed
    And the output should match:
      | Name:\\s+database-1                  |
      | Pods Status:                         |
      | Name:\\s+origin-ruby-sample          |
      | Tag                                |
      | Name:\\s+frontend                    |
      | Template:                            |

