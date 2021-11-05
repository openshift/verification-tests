Feature: oc_env.feature

  # @author xiuwang@redhat.com
  # @case_id OCP-11032
  @proxy
  @4.8 @4.7 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  Scenario: Set environment variables when creating application using non-DeploymentConfig template
    Given I have a project
    When I run the :new_app client command with:
      | template | cakephp-mysql-example |
      | env | OPCACHE_REVALIDATE_FREQ=3  |
      | env | APPLE1=apple               |
      | env | APPLE2=tesla               |
      | env | APPLE3=linux               |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=cakephp-mysql-example |
    Given I store in the clipboard the pods labeled:
      | name=cakephp-mysql-example |
    When I run the :set_env client command with:
      | resource | pods/<%= cb.pods[0].name%> |
      | list     | true                       |
    And the output should contain:
      | OPCACHE_REVALIDATE_FREQ=3 |
      | APPLE1=apple              |
      | APPLE2=tesla              |
      | APPLE3=linux              |

