@clusterlogging
@commonlogging
Feature: eventrouter related test

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: The Openshift Events be parsed
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Then I run the :new_app client command with:
      | app_repo | httpd-example |
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given logging eventrouter is installed in the cluster
    Given a pod becomes ready with labels:
      | component=eventrouter |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>   |
      | namespace     | openshift-logging |
      | since         | 5m                |
    Then the step should succeed
    And the output should contain:
      | "verb":  |
      | "event": |
      | "reason" |
    Given I wait for the "<index_name>" index to appear in the ES pod with labels "es-node-master=true"
    And I wait up to 300 seconds for the steps to pass:
    """
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | <index_name>*/_search?pretty' -d '{"_source":["kubernetes.event.*"],"sort": [{"@timestamp": {"order":"desc"}}],"query":{"term":{"kubernetes.container_name":"eventrouter"}}} |
      | op           | GET                                                                                                                                                                          |
    Then the step should succeed
    And the output should contain:
      | "event" :          |
      | "reason" :         |
      | "verb" :           |
      | "involvedObject" : |
    """

    Examples:
    | index_name  |
    | .operations | # @case_id OCP-25899
    | infra       | # @case_id OCP-29738
