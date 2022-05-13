Feature: Scheduler predicates and priority test suites

  # @author wjiang@redhat.com
  # @case_id OCP-12467
  @admin
  @inactive
  Scenario: Fixed predicates rules testing - MatchNodeSelector
    Given I have a project
    Given I obtain test data file "scheduler/pod_with_nodeselector.json"
    Given I run the :create client command with:
      | f | pod_with_nodeselector.json  |
    Then the step should succeed
    Given I run the :describe client command with:
      | resource  | pods            |
      | name      | nodeselect-pod  |
    Then the output should match:
      |  Status:\\s+Pending |
      | FailedScheduling.*(MatchNodeSeceltor\|node\(s\) didn't match node selector)|
    Given a node that can run pods in the "<%=project.name%>" project is selected
    Given label "OS=atomic" is added to the "<%=node.name%>" node
    Then the step should succeed
    Given the pod named "nodeselect-pod" becomes ready
    Then the expression should be true> pod.node_name == node.name

