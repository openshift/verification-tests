Feature: Node management

  # @author chaoyang@redhat.com
  # @case_id OCP-11084
  @admin
  @inactive
  Scenario: OCP-11084:Node admin can get nodes
    Given I have a project
    When I run the :get admin command with:
      |resource|nodes|
    Then the step should succeed
    Then the outputs should contain "Ready"
