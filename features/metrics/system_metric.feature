Feature: system metric related tests

  # @author pruan@redhat.com
  # @case_id OCP-15527
  @admin
  @destructive
  Scenario: Deploy Prometheus via ansible with default values
    Given the master version >= "3.7"
    Given I create a project with non-leading digit name
    And metrics service is installed with ansible using:
      | inventory | <%= BushSlicer::HOME %>/testdata/logging_metrics/default_inventory_prometheus |

  # @author chunchen@redhat.com
  # @case_id OCP-14162
  # @author xiazhao@redhat.com
  # @author penli@redhat.com
  @admin
  @destructive
  @smoke
  Scenario: Access heapster interface,Check jboss wildfly version from hawkular-metrics pod logs
    Given I create a project with non-leading digit name
    Given metrics service is installed in the system using:
      | inventory       | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-11821/inventory              |
      | deployer_config | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-11821/deployer_ocp11821.yaml |
    And I use the "openshift-infra" project
    Given a pod becomes ready with labels:
      | metrics-infra=hawkular-metrics |
    And I wait for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name    | <%= pod.name %>|
    And the output should contain:
      | JBoss EAP |
    """
    Given I wait for the steps to pass:
    """
    When I perform the :access_heapster rest request with:
      | project_name | <%=project.name%> |
    Then the step should succeed
    """
    When I perform the :access_pod_network_metrics rest request with:
      | project_name | <%=project.name%> |
      | pod_name     | <%=pod.name%>     |
      | type         | tx                |
    Then the step should succeed
    When I perform the :access_pod_network_metrics rest request with:
      | project_name | <%=project.name%> |
      | pod_name     | <%=pod.name%>     |
      | type         | rx                |
    Then the step should succeed

  # @author pruan@redhat.com
  # @case_id OCP-14519
  @admin
  @destructive
  Scenario: Show CPU,memory, network metrics statistics on pod page of openshift web console
    Given I create a project with non-leading digit name
    And metrics service is installed in the system
    And I switch to the first user
    Given I create a project with non-leading digit name
    And evaluation of `project.name` is stored in the :proj_1_name clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" becomes present
    Given I login via web console
    When I perform the :check_pod_metrics_tab web action with:
      | project_name | <%= project.name %> |
      | pod_name     | <%= pod.name %>     |
    Then the step should succeed
    And I run the :logout web console action
    # switch user
    And I switch to the second user
    Given I create a project with non-leading digit name
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/pods/pod_with_two_containers.json |
    Then the step should succeed
    And  the pod named "doublecontainers" becomes ready
    Given the second user is cluster-admin
    And I login via web console
    When I perform the :check_pod_metrics_tab web action with:
      | project_name | <%= project.name %> |
      | pod_name     | <%= pod.name %>     |
    Then the step should succeed
    When I perform the :check_pod_metrics_tab web action with:
      | project_name | <%= cb.proj_1_name %> |
      | pod_name     | hello-openshift       |
    Then the step should succeed

