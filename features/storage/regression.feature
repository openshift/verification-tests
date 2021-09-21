Feature: Regression testing cases

  # @author jhou@redhat.com
  # @case_id OCP-16485
  @admin
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  @aws-upi
  Scenario: RWO volumes are exclusively mounted on different nodes
    Given I have a project

    Given I obtain test data file "storage/misc/pvc.json"
    Given I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | ds            |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi           |

    Given I obtain test data file "storage/misc/damonset.json"
    When I run the :create admin command with:
      | f | damonset.json |
      | n | <%= project.name %>                                         |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should match:
      | (already\|conflict) |
    """
