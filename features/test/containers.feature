Feature: test container related support

  @admin
  @destructive
  Scenario: test methods for getting containers spec
    Given I create a project with non-leading digit name
    And logging service is installed in the system
    Given a pod becomes ready with labels:
      |  component=kibana,deployment=logging-kibana-1,deploymentconfig=logging-kibana,logging-infra=kibana,provider=openshift |
    # check kibana pods settings
    And evaluation of `pod.container(user: user, name: 'kibana').spec.memory_limit_raw` is stored in the :kibana_container_res_limit clipboard
    And evaluation of `pod.container(user: user, name: 'kibana-proxy').spec.memory_limit_raw` is stored in the :kibana_proxy_container_res_limit clipboard
    Then the expression should be true> cb.kibana_container_res_limit == "736Mi"
    Then the expression should be true> cb.kibana_proxy_container_res_limit == "256Mi"
    # check kibana dc settings
    And evaluation of `dc('logging-kibana').container_spec(user: user, name: 'kibana').memory_limit_raw` is stored in the :kibana_dc_res_limit clipboard
    And evaluation of `dc('logging-kibana').container_spec(user: user, name: 'kibana-proxy').memory_limit_raw` is stored in the :kibana_proxy_dc_res_limit clipboard
    Then the expression should be true> cb.kibana_container_res_limit == cb.kibana_dc_res_limit
    Then the expression should be true> cb.kibana_proxy_container_res_limit == cb.kibana_proxy_dc_res_limit
    # # check rc
    # And evaluation of `rc('logging-kibana-1').containers_spec(user: user, name: 'kibana').memory_limits` is stored in the :kibana_rc_res_limit clipboard
    # And evaluation of `rc('logging-kibana-1').containers_spec(user: user, name: 'kibana-proxy').memory_limits` is stored in the :kibana_proxy_rc_res_limit clipboard
    # Then the expression should be true> cb.kibana_container_res_limit == cb.kibana_rc_res_limit
    # Then the expression should be true> cb.kibana_proxy_container_res_limit == cb.kibana_proxy_rc_res_limit
    # check daemonset
    Then the expression should be true> daemon_set('logging-fluentd').container_spec(user: user, name: 'fluentd-elasticsearch').memory_limit_raw == "512Mi"
    And evaluation of `daemon_set('logging-fluentd').containers_spec(user: user)` is stored in the :specs clipboard

    # test deployment and replicaset
    Given I obtain test data file "deployment/hello-deployment-1.yaml"
    When I run the :create client command with:
      | f | hello-deployment-1.yaml |
    Then the step should succeed
    Given number of replicas of "hello-openshift" deployment becomes:
      | desired   | 10 |
      | current   | 10 |
      | updated   | 10 |
      | available | 10 |
    Given number of replicas of the current replica set for the "hello-openshift" deployment becomes:
      | desired  | 10 |
      | current  | 10 |
      | ready    | 10 |
    And the expression should be true> deployment.container_spec(user: user, name: 'hello-openshift').image_pull_policy == 'Always'
    And the expression should be true> deployment.container_spec(user: user, name: 'hello-openshift').termination_message_path == '/dev/termination-log'
