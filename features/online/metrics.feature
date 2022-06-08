Feature: Online metrics related tests

  # @author pruan@redhat.com
  # @case_id OCP-15214
  Scenario: OCP-15214 Ordinary user could view CPU,memory, network metrics statistics on pod page of openshift web console
    Given I have a project
    Given I login via web console
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" becomes present
    When I perform the :check_pod_metrics_tab web action with:
      | project_name | <%= project.name %> |
      | pod_name     | <%= pod.name %>     |
    Then the step should succeed

