Feature: rsh.feature

  # @author cryan@redhat.com
  # @case_id OCP-10658
  Scenario: OCP-10658 Check oc rsh for simpler access to a remote shell
    Given I have a project
    Then evaluation of `project.name` is stored in the :proj_name clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    Given the pod named "doublecontainers" becomes ready
    When I run the :rsh client command with:
      | pod         | doublecontainers |
      | command     | echo             |
      | command_arg | my_test_string   |
    Then the step should succeed
    And the output should contain "my_test_string"
    When I run the :rsh client command with:
      | c           | hello-openshift-fedora |
      | pod         | doublecontainers       |
      | command     | echo                   |
      | command_arg | my_test_string         |
    Then the step should succeed
    And the output should contain "my_test_string"
    When I run the :rsh client command with:
      | c           | hello-openshift-fedora |
      | shell       | /bin/bash              |
      | pod         | doublecontainers       |
      | command     | echo                   |
      | command_arg | my_test_string         |
    Then the step should succeed
    And the output should contain "my_test_string"
    Given I create a new project
    When I run the :rsh client command with:
      | n           | <%= cb.proj_name %> |
      | pod         | doublecontainers    |
      | command     | echo                |
      | command_arg | my_test_string      |
    Then the step should succeed
    And the output should contain "my_test_string"

