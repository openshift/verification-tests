Feature: kata smoke tests
  # @author pruan@redhat.com
  # @case_id OCP-41263
  @admin
  Scenario: [sandboxed containers] Namespace installed by operator
    Given kata container has been installed successfully
    Then the expression should be true> project.name == 'openshift-sandboxed-containers-operator'

