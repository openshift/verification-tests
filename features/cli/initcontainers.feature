Feature: InitContainers
  # @author dma@redhat.com
  # @case_id OCP-12166
  Scenario: InitContainer should failed after exceed activeDeadlineSeconds
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-deadline.yaml |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | pod       |
      | resource_name | hello-pod |
    Then the output should match:
      | hello-pod.*DeadlineExceeded |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-12222
  @admin
  Scenario: SCC rules should apply to init containers
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-privilege.yaml |
    Then the step should fail
    And the output should match:
      | forbidden.*unable to validate.**privileged.*Invalid value.*true |
    Given SCC "privileged" is added to the "default" user
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-privilege.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :exec client command with:
      | c            | wait      |
      | pod          | hello-pod |
      | exec_command | ls        |
    Then the step should succeed
    And the output should match:
      | bin |
      | dev |
    """
    Given SCC "privileged" is removed from the "default" user
    When I run the :exec client command with:
      | c            | wait      |
      | pod          | hello-pod |
      | exec_command | ls        |
    Then the step should fail
    And the output should match:
      | exec.*not allowed.*exceeds.*permissions.*privileged.*Invalid value.*true |

