Feature: Event related scenarios

  # @author chezhang@redhat.com
  # @case_id OCP-10751
  @admin
  Scenario: OCP-10751 check event compressed in kube
    Given I have a project
    When I run the :new_app admin command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/quota/quota_template.yaml |
      | param | CPU_VALUE=20    |
      | param | MEM_VALUE=1Gi   |
      | param | PV_VALUE=10     |
      | param | POD_VALUE=10    |
      | param | RC_VALUE=20     |
      | param | RQ_VALUE=1      |
      | param | SECRET_VALUE=10 |
      | param | SVC_VALUE=5     |
      | n     | <%= project.name %>            |
    Then the step should succeed
    When  I run the :describe client command with:
      | resource  | quota   |
      | name      | myquota |
    Then the output should match:
      | cpu\\s+0\\s+20                    |
      | memory\\s+0\\s+1Gi                |
      | persistentvolumeclaims\\s+0\\s+10 |
      | pods\\s+0\\s+10                   |
      | replicationcontrollers\\s+0\\s+20 |
      | resourcequotas\\s+1\\s+1          |
      | secrets\\s+9\\s+10                |
      | services\\s+0\\s+5                |
    When I run the :run client command with:
      | name      | nginx   |
      | image     | nginx   |
      | replicas  | 1       |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I get project events
    Then the output should match:
      | forbidden.*quota.*must specify cpu,memory |
    """
    When  I run the :describe client command with:
      | resource  | dc      |
      | name      | nginx   |
    Then the output should match:
      | forbidden.*quota.*must specify cpu,memory |

  # @author chezhang@redhat.com
  # @case_id OCP-10750
  Scenario: OCP-10750 Check normal and warning information for kubernetes events
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I get project events
    Then the output should match:
      | hello-openshift.*Normal\\s+Scheduled |
      | hello-openshift.*Normal\\s+Pulled    |
      | hello-openshift.*Normal\\s+Created   |
      | hello-openshift.*Normal\\s+Started   |
    When  I run the :describe client command with:
      | resource  | pods             |
      | name      | hello-openshift  |
    Then the output should match:
      | Normal\\s+Scheduled |
      | Normal\\s+Pulled    |
      | Normal\\s+Created   |
      | Normal\\s+Started   |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod-invalid.yaml |
    Then the step should succeed
    And I wait up to 240 seconds for the steps to pass:
    """
    When I get project events
    Then the output should match:
      | hello-openshift-invalid.*Normal\\s+Scheduled   |
      | hello-openshift-invalid.*Normal\\s+BackOff     |
      | hello-openshift-invalid.*Warning\\s+Failed     |
    """
    When  I run the :describe client command with:
      | resource  | pods                    |
      | name      | hello-openshift-invalid |
    Then the output should match:
      | Normal\\s+Scheduled   |
      | Normal\\s+BackOff     |
      | Warning\\s+Failed     |

  # @author dma@redhat.com
  # @case_id OCP-10208
  Scenario: OCP-10208 Event should show full failed reason when readiness probe failed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/tc533910/readiness-probe-exec.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :running
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    Then the output should match:
      | Unhealthy.*Readiness probe (failed\|errored):.*exec failed.*\\/bin\\/hello:\\s+no such file or directory |
    """

