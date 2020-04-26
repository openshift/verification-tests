Feature: InitContainers

  # @author dma@redhat.com
  # @case_id OCP-11318
  Scenario: App container run depends on initContainer results in pod
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-success.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" becomes ready
    Then I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    And the output should match:
      | Initialized\\s+True |
      | Ready\\s+True       |
    Given I ensure "hello-pod" pod is deleted
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-fail.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :failed
    When I get project pods
    And the output should contain "Init:Error"
    Then I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    And the output should match:
      | Initialized\\s+False |
      | Ready\\s+False       |

  # @author dma@redhat.com
  # @case_id OCP-11814
  Scenario: Check volume and readiness probe field in initContainer
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/volume-init-containers.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :running
    Then I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    And the output should match:
      | Initialized\\s+True |
      | Ready\\s+True       |
    Given I ensure "hello-pod" pod is deleted
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-readiness.yaml |
    Then the step should fail
    And the output should match:
      | spec.initContainers\[0\].readinessProbe: Invalid value.*must not be set for init containers|

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
  # @case_id OCP-11975
  @admin
  Scenario: Init containers properly apply to quota and limits
    Given I have a project
    When I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/quota.yaml |
      | n | <%= project.name %>                                                                               |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource | quota             |
      | name     | compute-resources |
    Then the output should match:
      | limits.cpu\\s+0\\s+2         |
      | limits.memory\\s+0\\s+2Gi    |
      | pods\\s+0\\s+4               |
      | requests.cpu\\s+0\\s+1       |
      | requests.memory\\s+0\\s+1Gi  |
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-quota-1.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota             |
      | name     | compute-resources |
    Then the output should match:
      | limits.cpu\\s+500m\\s+2         |
      | limits.memory\\s+400Mi\\s+2Gi   |
      | pods\\s+1\\s+4                  |
      | requests.cpu\\s+400m\\s+1       |
      | requests.memory\\s+300Mi\\s+1Gi |
    Given I ensure "hello-pod" pod is deleted
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/initContainers/init-containers-quota-2.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | quota             |
      | name     | compute-resources |
    Then the output should match:
      | limits.cpu\\s+300m\\s+2         |
      | limits.memory\\s+240Mi\\s+2Gi   |
      | pods\\s+1\\s+4                  |
      | requests.cpu\\s+200m\\s+1       |
      | requests.memory\\s+200Mi\\s+1Gi |
    When I run the :describe client command with:
      | resource | pods      |
      | name     | hello-pod |
    Then the output should match:
      | QoS.*Burstable |

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

