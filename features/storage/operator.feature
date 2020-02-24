Feature: Operator in storage related feature
  
  # @author chaoyang@redhat.com
  # @case_id OCP-27564
  @admin
  Scenario: CSI snapshot controller operator is installed by default
    When I run the :get admin command with:
      | resource | pod                                        |
      | n        | openshift-csi-snapshot-controller-operator |
    Then the step should succeed
    And the output should contain:
      | Running |
    When I run the :get admin command with:
      | resource | pod                               |
      | n        | openshift-csi-snapshot-controller |
    Then the step should succeed
    And the output should contain:
      | Running |

    Given evaluation of `cluster_version('version').version` is stored in the :ocp_version clipboard
    And evaluation of `cluster_operator('csi-snapshot-controller').condition(type: 'Available')` is stored in the :operator_status clipboard
    Then the expression should be true> cb.operator_status["status"]=="True"
    And the expression should be true> cluster_operator('csi-snapshot-controller').version_exists?(version: cb.ocp_version)

