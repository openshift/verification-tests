Feature: basic verification for upgrade testing
  # @author weinliu@redhat.com
  @upgrade-prepare
  @admin
  Scenario: Upgrade - Make sure multiple resources work well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given I ensure "node-upgrade" project is deleted
    When I run the :new_project client command with:
      | project_name | node-upgrade |
    And I use the "node-upgrade" project
    Given I obtain test data file "infrastructure/hpa/hpa-v2beta1-rc.yaml"
    When I run the :create client command with:
      | f | hpa-v2beta1-rc.yaml |
    Then the step should succeed
    Given 1 pod becomes ready with labels:
      | run=hello-openshift |
    Given I obtain test data file "infrastructure/hpa/resource-metrics-cpu.yaml"
    When I run the :create client command with:
      | f | resource-metrics-cpu.yaml |
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    Then expression should be true> hpa('resource-cpu').min_replicas(cached: false) == 2
    And expression should be true> hpa.max_replicas == 10
    And expression should be true> hpa.current_cpu_utilization_percentage == 0
    And expression should be true> hpa.target_cpu_utilization_percentage == 20
    And expression should be true> hpa.current_replicas == 2
    """
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create client command with:
      | f | daemonset.yaml |
    Then the step should succeed
    Given I obtain test data file "configmap/configmap.yaml"
    When I run the :create client command with:
      | f | configmap.yaml |
      | n | <%= project.name %>                                       |
    Then the step should succeed
    Given I obtain test data file "configmap/pod-configmap-volume1.yaml"
    When I run the :create client command with:
      | f | pod-configmap-volume1.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod-1" status becomes :succeeded


  # @author weinliu@redhat.com
  # @case_id OCP-13016
  @upgrade-check
  @admin
  @aws-ipi
  Scenario: Upgrade - Make sure multiple resources work well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "node-upgrade" project
    And admin ensures "node-upgrade" namespace is deleted after scenario
    Given I obtain test data file "infrastructure/hpa/hello-pod.yaml"
    When I run the :create client command with:
      | f | hello-pod.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :running within 60 seconds
    When I run the :expose client command with:
      | resource      | rc              |
      | resource name | hello-openshift |
      | port          | 8080            |
    Given I wait for the "hello-openshift" service to become ready
    When I run the :exec background client command with:
      | pod              | hello-pod                                                       |
      | oc_opts_end      |                                                                 |
      | exec_command     | sh                                                              |
      | exec_command_arg | -c                                                              |
      | exec_command_arg | while true;do curl -sS http://<%= service.url %>>/dev/null;done |
    Then the step should succeed
    Given I wait up to 600 seconds for the steps to pass:
    """
    Then expression should be true> hpa('resource-cpu').current_replicas(cached: false) > 2
    And expression should be true> hpa.current_cpu_utilization_percentage > hpa.target_cpu_utilization_percentage
    """
    Given I ensure "hello-pod" pod is deleted
    Then I wait up to 600 seconds for the steps to pass:
    """
    Then expression should be true> hpa('resource-cpu').current_cpu_utilization_percentage(cached: false) == 0
    And expression should be true> hpa.current_replicas == 2
    """
    Then I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | daemonset       |
      | name     | hello-daemonset |
    Then the output should match "0 Waiting.*0 Succeeded.*0 Failed"
    """
    When I run the :get client command with:
      | resource | configmap |
    Then the output should match:
      | NAME.*DATA        |
      | special-config.*2 |
    When I run the :describe client command with:
      | resource | configmap      |
      | name     | special-config |
    Then the output should match:
      | special.how  |
      | special.type |
    Given I obtain test data file "configmap/pod-configmap-volume2.yaml"
    When I run the :create client command with:
          | f | pod-configmap-volume2.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod-2" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod-2 |
    Then the step should succeed
    And the output should contain:
      | charm |
