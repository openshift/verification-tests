Feature: oc patch/apply related scenarios

  # @author xxia@redhat.com
  # @case_id OCP-10696
  @smoke
  Scenario: OCP-10696:Workloads oc patch can update one or more fields of rescource
    Given I have a project
    And I run the :run client command with:
      | name      | hello             |
      | image     | <%= project_docker_repo %>openshift/hello-openshift |
    Then the step should succeed
    Given I wait until the status of deployment "hello" becomes :running
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"spec":{"replicas":2}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "2"
    """
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"metadata":{"labels":{"template":"newtemp","name1":"value1"}},"spec":{"replicas":3}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.metadata.labels.template}} {{.metadata.labels.name1}} {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "newtemp value1 3"
    """

