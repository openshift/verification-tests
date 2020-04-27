@clusterlogging
@commonlogging
Feature: eventrouter related test

  # @author qitang@redhat.com
  # @case_id OCP-25899
  @admin
  @destructive
  Scenario: The Openshift Events be parsed
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
    Given I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the steps to pass:
    """
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | .operations*/_search?pretty' -d '{"_source":["kubernetes.event.*"],"sort": [{"@timestamp": {"order":"desc"}}],"query":{"term":{"kubernetes.container_name":"eventrouter"}}} |
      | op           | GET                                                                                                                                                                         |
    Then the step should succeed
    And the output should contain:
      | "event" :          |
      | "reason" :         |
      | "verb" :           |
      | "involvedObject" : |
    # Then the expression should be true> @result[:parsed]['hits']['hits'].last["_source"]["kubernetes"]["event"].present? == true
    # And the expression should be true> ["ADDED", "UPDATED", "MODIFIED", "DELETED"].include? @result[:parsed]['hits']['hits'].last["_source"]["kubernetes"]["event"]["verb"]
    """

  # @author anli@redhat.com
  # @case_id OCP-29738
  @admin
  Scenario Outline:
    Given I store master major version in the :master_version clipboard
    Given the extra image namespace is stored in the :registry_namespace clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :cur_project clipboard
    When I run the :new_app client command with:
      | file | <%= BushSlicer::HOME %>/features/tierN/testdata/logging/eventrouter/internal_eventrouter.yaml|
      | p    | IMAGE=<%=cb[registry_namespace]%>ose-logging-eventrouter:<%= cb[master_version] %> |
      | p    | NAMESPACE=<%= cb[cur_project] %> |
    Then the step should succeed
    Then a pod becomes ready with labels:
      | component=eventrouter |
