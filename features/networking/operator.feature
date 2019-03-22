Feature: Operator related networking scenarios
  
  # @auther anusaxen@redhat.com
  # @case_id OCP-22704
  @admin
  Scenario: The clusteroperator should be able to reflect the network operator version corresponding to the OCP version
    Given I use the "openshift-sdn" project
    #Getting OCP version
    When I run the :get admin command with:
      | resource | clusterversion                                |
      | output   | jsonpath='{.items[*].status.desired.version}' |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :ocp_version clipboard

    #Making sure that network operator AVAILABLE value is True 
    When I run the :get admin command with:
      | resource | clusteroperators.config.openshift.io/network                   |
      | output   | jsonpath='{.status.conditions[?(@.type=="Available")].status}' |
    Then the step should succeed
    And the output should contain "True"

    #Make sure that network operator version matches with ocp version
    When I run the :get admin command with:
      | resource | clusteroperators.config.openshift.io/network |
      | output   | jsonpath='{.status.versions[*].version}'     |
    Then the step should succeed
    And the output should equal "<%= cb.ocp_version %>"
