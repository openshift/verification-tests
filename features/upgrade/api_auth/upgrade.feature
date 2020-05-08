Feature: apiserver and auth related upgrade check
  # @author pmali@redhat.com
  # @case_id OCP-22734
  @upgrade-prepare
  Scenario: Check Authentication operators and operands are upgraded correctly - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author pmali@redhat.com
  # @case_id OCP-22734
  @upgrade-check
  @admin
  Scenario: Check Authentication operators and operands are upgraded correctly
    Given the "authentication" operator version matches the current cluster version

    # Check cluster operators should be in correct status
    Given the expression should be true> cluster_operator('authentication').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Upgradeable')['status'] == "True"
    
    # operator pod image
    When I run the :get admin command with:
      | resource  | po                                            |
      | n         | openshift-authentication-operator             |
      | o         | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :auth_operator_image clipboard
    
    # Not Need for now, commenting out code part
 
    # operator pod env value
    #When I run the :get admin command with:
    #  | resource  | po                                                     |
    #  | n         | openshift-authentication-operator                      |
    #  | o         | jsonpath={.items[0].spec.containers[0].env[0].value}   |
    #Then the step should succeed
    #And evaluation of `@result[:response]` is stored in the :auth_operator_env_value clipboard

    # operands pod image 
    #When I run the :get admin command with:
    #  | resource  | po                                            |
    #  | n         | openshift-authentication                      |
    #  | o         | jsonpath={.items[0].spec.containers[0].image} |
    #Then the step should succeed
    #And evaluation of `@result[:response]` is stored in the :auth_image clipboard

    # Check the pod image is the same as the operator specified:
    #Given the expression should be true> cb.auth_image == cb.auth_operator_env_value
    
    # Check cluster version
    When I run the :get admin command with:
      | resource | clusterversion/version           |
      | o        | jsonpath={.status.desired.image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :payload_image clipboard

    # Check the payload info
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`
    And I run commands on the host:
      | <%= cb.oc_adm_release_info %> --image-for=cluster-authentication-operator      |
    Then the step should succeed
    And the output should contain:
      | <%= cb.auth_operator_image %> |
