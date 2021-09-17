Feature: oc_delete.feature

  # @author cryan@redhat.com
  # @case_id OCP-11184
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Gracefully delete a pod with '--grace-period' option
    Given I have a project
    Given I obtain test data file "pods/graceful-delete/10.json"
    When I run the :create client command with:
      | f | 10.json |
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace10 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds"
    When I run the :delete background client command with:
      | object_type | pod |
      | l | name=graceful |
      | grace_period | 20 |
    Then the step should succeed
    Given 10 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should contain "Terminating"
    #The full 20 seconds have passed after this step
    Given 25 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"
    Given I obtain test data file "pods/graceful-delete/10.json"
    When I run the :create client command with:
      | f | 10.json |
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace10 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
      | grace_period | 0 |
    Then the step should succeed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id OCP-12048
  # @bug_id 1277101
  @admin
  @inactive
  Scenario: The namespace will not be deleted until all pods gracefully terminate
    Given I have a project
    And evaluation of `project.name` is stored in the :prj1 clipboard
    Given I obtain test data file "pods/graceful-delete/40.json"
    When I run the :create client command with:
      | f | 40.json |
    And a pod becomes ready with labels:
      | name=graceful |
    And evaluation of `pod.name` is stored in the :pod clipboard
    Given the project is deleted
    Given 10 seconds have passed
    When I run the :get admin command with:
      | resource | namespaces |
    #The namespace should not be immediately deleted,
    #because all pods in it have a graceful termination period.
    #If the namespace does not exist, it is due to bug 1277101
    #as noted in the @bug_id above.
    Then the output should match "<%= cb.prj1 %>\s+Terminating"
    When I run the :get admin command with:
      | resource | pods |
      | all_namespaces | true |
    And the output should match "<%= cb.pod %>.*Terminating"
    Given I wait for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | pods |
      | all_namespaces | true |
    Then the step should succeed
    And the output should not match "<%= cb.pod %>.*Terminating"
    """

  # @author cryan@redhat.com
  # @case_id OCP-10705
  @inactive
  Scenario: Default termination grace period is 30s if it's not set
    Given I have a project
    Given I obtain test data file "pods/graceful-delete/default.json"
    When I run the :create client command with:
      | f | default.json |
    Given the pod named "grace-default" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace-default |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds: 30"
    When I run the :delete background client command with:
      | object_type | pod |
      | l | name=graceful |
    Then the step should succeed
    Given 20 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should contain "Terminating"
    Given 25 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id OCP-12144
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Verify pod is gracefully deleted when DeletionGracePeriodSeconds is specified.
    Given I have a project
    Given I obtain test data file "pods/graceful-delete/10.json"
    When I run the :create client command with:
      | f | 10.json |
    Then the step should succeed
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource      | pods    |
      | resource_name | grace10 |
      | o             | yaml    |
    Then the output should contain "terminationGracePeriodSeconds: 10"
    When I run the :delete background client command with:
      | object_type | pod           |
      | l           | name=graceful |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods
    Then the output should contain "Terminating"
    """
    And I wait for the resource "pod" named "grace10" to disappear within 120 seconds

  # @author cryan@redhat.com
  # @case_id OCP-11526
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Pod should be immediately deleted if TerminationGracePeriodSeconds is 0
    Given I have a project
    Given I obtain test data file "pods/graceful-delete/0.json"
    When I run the :create client command with:
      | f | 0.json |
    Given the pod named "grace0" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace0 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds: 0"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
    Then the step should succeed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

