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

    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                  |
      | query | ALERTS{alertname="<alertname>"} |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["data"]["result"][0]["metric"]["alertstate"] =~ /pending|firing/
    """

    Examples:
      | operator                    | namespace                          | alertname                     |
      | cluster-autoscaler-operator | openshift-machine-api              | ClusterAutoscalerOperatorDown | # @case_id OCP-26250
      | machine-api-operator        | openshift-machine-api              | MachineAPIOperatorDown        | # @case_id OCP-26248
      | machine-approver            | openshift-cluster-machine-approver | ClusterMachineApproverDown    | # @case_id OCP-26110
