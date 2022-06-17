Feature: Features about k8s deployments

# @author etrott@redhat.com
  # @case_id OCP-12329
  Scenario: OCP-12329 Check k8s deployments on Deployments page
    Given the master version >= "3.4"
    Given I create a new project
    When I perform the :goto_deployments_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I run the :check_no_dc_to_show web console action
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc536600/hello-deployment-1.yaml |
    Then the step should succeed
    And I run the :run client command with:
      | name  | testdc                |
      | image | aosqe/hello-openshift |
    Then the step should succeed
    When I run the :get client command with:
      | resource | dc |
    Then the output should contain:
      | testdc |
    When I run the :get client command with:
      | resource | rc |
    Then the output should contain:
      | testdc-1 |
    When I run the :get client command with:
      | resource | deployment |
    Then the output should contain:
      | hello-openshift |
    When I run the :get client command with:
      | resource | replicaset |
    Then the output should contain:
      | hello-openshift |
    When I perform the :check_resource_on_deployment_page web console action with:
      | project_name  | <%= project.name %>       |
      | resource      | dc                        |
      | resource_type | Deployment Config         |
      | resource_name | testdc                    |
      | last_version  | #1                        |
    Then the step should succeed
    When I perform the :check_deployment_on_deployment_page web console action with:
      | project_name  | <%= project.name %>                                                                  |
      | resource      | deployment                                                                           |
      | resource_type | Deployments                                                                          |
      | resource_name | hello-openshift                                                                      |
      | last_version  | #1                                                                                   |
      | replicas      | <%= deployment("hello-openshift").replicas(user:user) %> replica                     |
      | strategy_type | <%= deployment("hello-openshift").strategy["type"].sub("U", " u") %>                 |
    Then the step should succeed
    When I perform the :click_on_deployment_last_version_on_deployments_page web console action with:
      | resource_name | hello-openshift |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | deployment                                                                                                 |
      | resource_name | hello-openshift                                                                                            |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"hello-openshift","image":"aosqe/hello-openshift"}]}}}} |
    Then the step should succeed
    When I perform the :check_replicas_less_than web console action with:
      | replicas | <%= deployment("hello-openshift").strategy["rollingUpdate"]["maxUnavailable"] %> |
    Then the step should succeed
    When I perform the :goto_deployments_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_deployment_on_deployment_page web console action with:
      | project_name  | <%= project.name %> |
      | resource      | deployment          |
      | resource_type | Deployments         |
      | resource_name | hello-openshift     |
      | last_version  | #2                  |
      | replicas      | 1 replica           |
      | strategy_type | Rolling update      |
    Then the step should succeed
    When I perform the :click_on_one_deployment web console action with:
      | k8s_deployments_name | hello-openshift |
    Then the step should succeed
    When I perform the :edit_replicas_on_deployment_page web console action with:
      | replicas | 2 |
    Then the step should succeed
    When I perform the :check_rs_on_one_deployment_page web console action with:
      | rs_name  | hello-openshift |
      | version  | #2              |
      | replicas | 2               |
    Then the step should succeed
    When I perform the :edit_replicas_on_deployment_page web console action with:
      | replicas | 1 |
    Then the step should succeed
    When I perform the :check_rs_on_one_deployment_page web console action with:
      | rs_name  | hello-openshift |
      | version  | #2              |
      | replicas | 1               |
    Then the step should succeed

