Feature: system metric related tests

  # @author pruan@redhat.com
  # @case_id OCP-15527
  @admin
  @destructive
  Scenario: OCP-15527 Deploy Prometheus via ansible with default values
    Given the master version >= "3.7"
    Given I create a project with non-leading digit name
    And metrics service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_inventory_prometheus |

  # @author pruan@redhat.com
  # @case_id OCP-10927
  @admin
  @destructive
  Scenario: OCP-10927 Access the external Hawkular Metrics API interface as cluster-admin
    Given I have a project
    Given metrics service is installed in the system using:
      | inventory       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11821/inventory              |
      | deployer_config | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11821/deployer_ocp11821.yaml |
    And I switch to the first user
    And evaluation of `user.cached_tokens.first` is stored in the :user_token clipboard
    Given cluster role "cluster-admin" is added to the "first" user
    And I wait for the steps to pass:
    """
    And I perform the GET metrics rest request with:
      | project_name | _system              |
      | path         | /metrics/gauges      |
      | token        | <%= cb.user_token %> |
    Then the expression should be true> @result[:exitstatus] == 200
    """
    And evaluation of `@result[:parsed].map { |e| e['type'] }.uniq` is stored in the :gauge_result clipboard
    And the expression should be true> cb.gauge_result == ['gauge']
    And I wait for the steps to pass:
    """
    And I perform the GET metrics rest request with:
      | project_name | _system              |
      | path         | /metrics/counters    |
      | token        | <%= cb.user_token %> |
    Then the expression should be true> @result[:exitstatus] == 200
    """
    And evaluation of `@result[:parsed].map { |e| e['type'] }.uniq` is stored in the :counter_result clipboard
    And the expression should be true> cb.counter_result == ['counter']

  # @author chunchen@redhat.com
  # @case_id OCP-14162
  # @author xiazhao@redhat.com
  # @case_id OCP-11574
  # @author penli@redhat.com
  @admin
  @destructive
  @smoke
  Scenario: OCP-14162 Access heapster interface,Check jboss wildfly version from hawkular-metrics pod logs
    Given I create a project with non-leading digit name
    Given metrics service is installed in the system using:
      | inventory       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11821/inventory              |
      | deployer_config | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11821/deployer_ocp11821.yaml |
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
  Scenario: OCP-14519 Show CPU,memory, network metrics statistics on pod page of openshift web console
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
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
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

