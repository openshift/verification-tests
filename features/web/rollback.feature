Feature: Deployments rollback features

  # @author yapei@redhat.com
  Scenario Outline: rollback from web console
    Given I have a project
    # create deployment from template on web console
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    And evaluation of `"hooks"` is stored in the :dc_name clipboard
    # wait to be deployed on web console
    When I perform the :wait_latest_deployments_to_deployed web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>  |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :complete
    # replace deploymentconfig
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    # wait to be deployed on web console
    When I perform the :wait_latest_deployments_to_deployed web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>  |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :complete
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "Rolling"         |
      | "type": "ImageChange"     |
      | "replicas": 2             |
      | "value": "Plqe5Wevchange" |
    # rollback
    When I perform the :click_specific_no_of_deploy web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>   |
      | deploy_number | 1 |
    Then the step should succeed
    When I run the :<rollback_op> web console action
    Then the step should succeed
    # check latest deployment no is 3
    When I perform the :wait_latest_deployments_to_deployed web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>  |
    Then the step should succeed
    When I perform the :check_latest_deployment_version web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | <%= cb.dc_name %>   |
      | latest_deployment_version | 3      |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "<changed_val1>" |
      | "type": "<changed_val2>"   |
      | "replicas": <changed_val3> |
      | "value": "Plqe5Wev" |
    Examples:
      | rollback_op              | changed_val1 | changed_val2 | changed_val3 |
      | rollback_none_components | Rolling      | ImageChange  | 2            | # @case_id OCP-11167
      | rollback_one_component   | Rolling      | ConfigChange | 2            | # @case_id OCP-11741
      | rollback_two_components  | Recreate     | ImageChange  | 1            | # @case_id OCP-11914
      | rollback_all_components  | Recreate     | ConfigChange | 1            | # @case_id OCP-11511

