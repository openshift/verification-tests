Feature: Alerting for machine-api

  # @author jhou@redhat.com
  @admin
  @destructive
  Scenario Outline: Alert should be fired when operator is down
    Given I switch to cluster admin pseudo user

    # scale down cvo and operators
    When I run the :scale admin command with:
      | resource | deployment                |
      | name     | cluster-version-operator  |
      | replicas | 0                         |
      | n        | openshift-cluster-version |
    Then the step should succeed
    And I register clean-up steps:
    """
    When I run the :scale admin command with:
      | resource | deployment                |
      | name     | cluster-version-operator  |
      | replicas | 1                         |
      | n        | openshift-cluster-version |
    Then the step should succeed
    """
    When I run the :scale admin command with:
      | resource | deployment  |
      | name     | <operator>  |
      | replicas | 0           |
      | n        | <namespace> |
    Then the step should succeed
    And I register clean-up steps:
    """
    When I run the :scale admin command with:
      | resource | deployment  |
      | name     | <operator>  |
      | replicas | 1           |
      | n        | <namespace> |
    Then the step should succeed
    """

    And I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :token clipboard

    # verify alert is fired by querying prometheus http api
    And I wait up to 180 seconds for the steps to pass:
    """
    When I run the :exec admin command with:
      | n                | openshift-monitoring                                                                                                                                                                |
      | pod              | prometheus-k8s-0                                                                                                                                                                    |
      | c                | prometheus                                                                                                                                                                          |
      | oc_opts_end      |                                                                                                                                                                                     |
      | exec_command     | sh                                                                                                                                                                                  |
      | exec_command_arg | -c                                                                                                                                                                                  |
      | exec_command_arg | curl -G -s -k -H "Authorization: Bearer <%= cb.token %>" --data-urlencode 'query=ALERTS{alertname="<alertname>"}' https://prometheus-k8s.openshift-monitoring.svc:9091/api/v1/query |
    Then the step should succeed
    And the output should match:
      | "alertstate":"pending\|firing" |
    """

    Examples:
      | operator                    | namespace                          | alertname                     |
      | cluster-autoscaler-operator | openshift-machine-api              | ClusterAutoscalerOperatorDown | # @case_id OCP-26250
      | machine-api-operator        | openshift-machine-api              | MachineAPIOperatorDown        | # @case_id OCP-26248
      | machine-approver            | openshift-cluster-machine-approver | ClusterMachineApproverDown    | # @case_id OCP-26110
