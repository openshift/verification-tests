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

  # @auther anusaxen@redhat.com
  # @case_id OCP-22706
  @admin
  @destructive
  Scenario: The clusteroperator should be able to reflect the correct version field post bad network operator config

    Given the master version >= "4.0"
    #Getting OCP version
    Given evaluation of `cluster_version('version').version` is stored in the :ocp_version clipboard
    #Making sure that operator is not Failing before proceesing further steps
    And evaluation of `cluster_operator('network').condition(type: 'Failing')` is stored in the :failing_status_before_patch clipboard
    Then the expression should be true> cb.failing_status_before_patch["status"]=="False"
    #Editing networks.config.openshift.io cluster to reflect bad config like changing networktype from OpenShiftSDN to OpenShift
    When I run the :patch admin command with:
      | resource      | networks.config.openshift.io         |
      | resource_name | cluster                              |
      | p             | {"spec":{"networkType":"OpenShift"}} |
      | type          | merge                                |
    Then the step should succeed

    #Normally it takes 5-10 seconds for network config update to reconcile across the cluster but taking 20 seconds wait to make sure that Failing status becomes True post bad patch
    Given 20 seconds have passed
    And evaluation of `cluster_operator('network').condition(type: 'Failing',cached: false)` is stored in the :failing_status_post_patch clipboard
    Then the expression should be true> cb.failing_status_post_patch["status"]=="True"
    And the expression should be true> cluster_operator('network').version_exists?(version: cb.ocp_version)
    
    #Registering clean-up steps to move networkType back to OpenShiftSDN and to check Failing status is False before test exits
    Given I register clean-up steps:
    """
    When I run the :patch admin command with:
      | resource      | networks.config.openshift.io            |
      | resource_name | cluster                                 |
      | p             | {"spec":{"networkType":"OpenShiftSDN"}} |
      | type          | merge                                   |
    Then the step should succeed
    20 seconds have passed
    evaluation of `cluster_operator('network').condition(type: 'Failing',cached: false)` is stored in the :failing_status clipboard
    the expression should be true> cb.failing_status["status"]=="False"
    """
