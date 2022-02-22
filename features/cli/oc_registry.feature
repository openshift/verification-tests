Feature: oc registry command scenarios

  # @author wzheng@redhat.com
  # @case_id OCP-21926
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  Scenario: Check function of oc registry command
    Given I have a project
    When I run the :registry_info client command with:
      | internal | true |
    Then the step should succeed
    And the output should contain:
      | image-registry.openshift-image-registry.svc:5000 |
    When I run the :registry_info client command with:
      | internal | true |
      | quiet    | true |
    Then the step should fail
    And the output should contain:
      | error |
    When I run the :registry_info client command with:
      | internal | 123 |
    Then the step should fail
    And the output should contain:
      | invalid |
    When I run the :registry_info client command with:
      | quiet  | 123 |
    Then the step should fail
    And the output should contain:
      | invalid |
    When I run the :registry_login client command with:
      | z          | default |
      | skip-check | true    |
    Then the step should succeed
    And the output should contain:
      | Saved credentials |
    When I run the :registry_login client command with:
      | z          | default |
      | skip-check | 123     |
    Then the step should fail
    And the output should contain:
      | invalid |

