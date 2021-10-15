Feature: route related features via cli

  # @author cryan@redhat.com
  # @case_id OCP-10629
  @proxy
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Expose routes from services
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/sclorg/s2i-perl-container |
      | l | app=test-perl|
      | context_dir | 5.20/test/sample-test-app/ |
      | name | myapp |
    Then the step should succeed
    And the "myapp-1" build completed
    Given I wait for the "myapp" service to become ready up to 300 seconds
    When I expose the "myapp" service
    Then the step should succeed
    Given I get project routes
    And the output should match:
      | myapp .* 8080    |
    When I run the :describe client command with:
      | resource | route |
      | name     | myapp |
    Then the step should succeed
    And the output should match "Labels:\s+app=test-perl"
    When I wait for a web server to become available via the "myapp" route
    Then the output should contain "Everything is fine"

  # @author cryan@redhat.com
  # @case_id OCP-12022
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Be unable to add an existed alias name for service
    Given I have a project
    Given I obtain test data file "routing/unsecure/route_unsecure.json"
    When I run the :create client command with:
      | f | route_unsecure.json |
    Then the step should succeed
    Given I obtain test data file "routing/unsecure/route_unsecure.json"
    When I run the :create client command with:
      | f | route_unsecure.json |
    Then the step should fail
    And the output should contain ""route" already exists"

