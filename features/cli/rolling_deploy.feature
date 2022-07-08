Feature: rolling deployment related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-12359
  @inactive
  Scenario: OCP-12359:Workloads Rolling-update pods with default value for maxSurge/maxUnavailable
    Given I have a project
    Given I obtain test data file "deployment/rolling.json"
    When I run the :create client command with:
      | f | rolling.json |
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 3     |
    And 3 pods become ready with labels:
      | name=hello-openshift |
    And I wait up to 120 seconds for the steps to pass:
    """
    And I run the :get client command with:
      | resource | dc |
      | resource_name | hooks |
      | output | yaml |
    Then the output should contain:
      | replicas: 3  |
      | maxSurge: 25% |
      | maxUnavailable: 25%  |
    """
    When I run the :rollout_latest client command with:
      | resource | dc/hooks |
    Then the step should succeed
    And the pod named "hooks-2-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-2-deploy" until it becomes :succeeded
    And the output should contain:
      | keep 3 pods available, don't exceed 4 pods |
    And I replace resource "dc" named "hooks":
      | maxUnavailable: 25% | maxUnavailable: 1 |
      | maxSurge: 25% | maxSurge: 2             |
    Then the step should succeed
    When I run the :rollout_latest client command with:
      | resource | dc/hooks |
    Then the step should succeed
    And the pod named "hooks-3-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-3-deploy" until it becomes :succeeded
    And the output should contain:
      | keep 2 pods available, don't exceed 5 pods |
