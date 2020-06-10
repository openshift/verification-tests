Feature: Seccomp

  # @author wmeng@redhat.com
  # @case_id OCP-10483
  Scenario: seccomp=unconfined used by default
    Given I have a project
    Given I obtain test data file "pods/hello-pod.json"
    When I run the :create client command with:
      | filename  | hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I execute on the pod:
      | grep | Seccomp | /proc/self/status |
    Then the output should contain:
      | 0 |
    And the output should not contain:
      | 2 |

