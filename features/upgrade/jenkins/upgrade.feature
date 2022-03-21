Feature: Jenkins feature upgrade test

  # @author xiuwang@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @console
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @gcp-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  Scenario: Jenkins feature upgrade test - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | jenkins-upgrade |
    Then the step should succeed
    When I use the "jenkins-upgrade" project
    And I have a jenkins v2 application
    Given I have a jenkins browser
    And I log in to jenkins

  # @author xiuwang@redhat.com
  # @case_id OCP-16932
  @upgrade-check
  @users=upuser1,upuser2
  @console
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @gcp-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  @upgrade
  Scenario: Jenkins feature upgrade test
    Given I switch to the first user
    When I use the "jenkins-upgrade" project
    Given I wait for the "jenkins" service to become ready up to 300 seconds
    Given I have a browser with:
      | rules    | lib/rules/web/images/jenkins_2/                                   |
      | base_url | https://<%= route("jenkins", service("jenkins")).dns(by: user) %> |
    And I log in to jenkins
