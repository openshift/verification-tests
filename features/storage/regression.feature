Feature: Regression testing cases

  # @author jhou@redhat.com
  # @case_id OCP-16485
  @admin
  Scenario: OCP-16485 RWO volumes are exclusively mounted on different nodes
    Given I have a project

    Given I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                         | ds            |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi           |
    And the "ds" PVC becomes :bound

    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/damonset.json |
      | n | <%= project.name %>                                                                                      |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should contain:
      | already |
    """

