Feature: Operator related networking scenarios

  # @auther anusaxen@redhat.com
  # @case_id OCP-22704
  @admin
  Scenario: The clusteroperator should be able to reflect the network operator version corresponding to the OCP version

    Given the master version > "3.11"
    #Getting OCP version
    Given evaluation of `cluster_version('version').version` is stored in the :ocp_version clipboard
    And evaluation of `cluster_operator('network').condition(type: 'Available')` is stored in the :operator_status clipboard
    #Making sure that network operator AVAILABLE status value is True
    Then the expression should be true> cb.operator_status["status"]=="True"
    #Confirm whether network operator version matches with ocp version
    And the expression should be true> cluster_operator('network').version_exists?(version: cb.ocp_version)
