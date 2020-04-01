Feature: Regression testing cases

  # @author jhou@redhat.com
  # @case_id OCP-16485
  @admin
  Scenario: RWO volumes are exclusively mounted on different nodes
    Given I have a project

    Given I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                         | ds            |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi           |

    When I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/misc/damonset.json |
      | n | <%= project.name %>                                                                           |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should match:
      | (already\|conflict) |
    """
