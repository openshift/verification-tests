Feature: custombuild.feature

  # @author wzheng@redhat.com
  # @case_id OCP-11443
  @admin
  Scenario: OCP-11443 Build with custom image - origin-custom-docker-builder
    Given cluster role "system:build-strategy-custom" is added to the "first" user
    Then the step should succeed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/release-3.11/examples/sample-app/application-template-custombuild.json |
    Then the step should succeed
    And I create a new application with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given I wait for the pod named "frontend-1-deploy" to die
    Given 2 pods become ready with labels:
      | name=frontend |
    When I get project service named "frontend" as JSON
    Then the step should succeed
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard
    When I get project pods as JSON
    Then the step should succeed
    Given evaluation of `@result[:parsed]['items'][1]['metadata']['name']` is stored in the :pod_name clipboard
    Given I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod | <%= cb.pod_name %> |
      |oc_opts_end||
      | exec_command | curl |
      | exec_command_arg | <%= cb.service_ip%>:5432 |
    Then the output should contain "Hello from OpenShift v3"
    """
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the output should contain:
      | Status   |
      | Started  |
      | Duration |

