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
      | resource | po                                            |
      | n        | openshift-authentication-operator             |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :auth_operator_image clipboard

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
      | <%= cb.oc_adm_release_info %> --image-for=cluster-authentication-operator |
    Then the step should succeed
    And the output should contain:
      | <%= cb.auth_operator_image %> |

  # @author xxia@redhat.com
  @upgrade-prepare
  Scenario: Check apiserver operators and operands are upgraded correctly - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author xxia@redhat.com
  # @case_id OCP-22673
  @upgrade-check
  @admin
  Scenario: Check apiserver operators and operands are upgraded correctly
    Given the "kube-apiserver" operator version matches the current cluster version
    And the "openshift-apiserver" operator version matches the current cluster version
    # Check cluster operators should be in correct status
    Given the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Upgradeable')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Upgradeable')['status'] == "True"
    # operators
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-kube-apiserver-operator             |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :kas_operator_image clipboard
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-apiserver-operator                  |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :oas_operator_image clipboard
    # operands
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-kube-apiserver                      |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :kas_image clipboard
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-apiserver                           |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :oas_image clipboard

    When I run the :get admin command with:
      | resource | clusterversion/version           |
      | o        | jsonpath={.status.desired.image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :payload_image clipboard
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`
    And I run commands on the host:
      | <%= cb.oc_adm_release_info %> --image-for=cluster-kube-apiserver-operator      |
      | <%= cb.oc_adm_release_info %> --image-for=cluster-openshift-apiserver-operator |
      | <%= cb.oc_adm_release_info %> --image-for=hyperkube                            |
      | <%= cb.oc_adm_release_info %> --image-for=openshift-apiserver                  |
    Then the step should succeed
    And the output should contain:
      | <%= cb.kas_operator_image %> |
      | <%= cb.oas_operator_image %> |
      | <%= cb.kas_image %>          |
      | <%= cb.oas_image %>          |
