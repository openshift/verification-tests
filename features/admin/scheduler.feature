Feature: Scheduler related scenarios

  # @author wmeng@redhat.com
  # @case_id OCP-14582
  Scenario: OCP-14582 When no scheduler name is supplied, the pod is automatically scheduled using the default-scheduler
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/scheduler/multiple-schedulers/pod-no-scheduler.yaml |
    Then the step should succeed
    Given the pod named "no-scheduler" becomes ready
    When I run the :describe client command with:
      | resource | pods         |
      | name     | no-scheduler |
    Then the output should match:
      | Status:\\s+Running |
      | default-scheduler  |

