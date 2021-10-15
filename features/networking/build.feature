Feature: Testing the isolation during build scenarios

  # @author zzhao@redhat.com
  # @bug_id 1487652
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario Outline: Build-container is constrained to access other projects pod for multitenant plugin
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `service("test-service").ip(user: user)` is stored in the :p1svcip clipboard
    And evaluation of `service("test-service").ports(user: user)[0].dig("port")` is stored in the :p1svcport clipboard

    Given I switch to the second user
    And I have a project
    When I run the :new_app client command with:
      | app_repo | <repo> |
    Then the step should succeed
    And the "ruby-docker-test-1" build was created
    When I run the :delete client command with:
      | object_type       | build         |
      | object_name_or_id | ruby-docker-test-1 |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | bc |
      | resource_name | ruby-docker-test |
      | p             | {"spec": {"strategy": {"<strategy>": {"env": [{"name": "SVC_IP","value": "<%= cb.p1svcip %>:<%= cb.p1svcport %>"}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-docker-test |
    Then the step should succeed
    And the "ruby-docker-test-2" build was created
    And I wait up to 400 seconds for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name | build/ruby-docker-test-2 |
    Then the output should not contain "Hello OpenShift"
    Then the output should contain "Connection timed out after"
    """

    Examples:
      | type   | repo                                                           | strategy       |
      | Docker | https://github.com/zhaozhanqi/ruby-docker-test/#isolation      | dockerStrategy | # @case_id OCP-15741
      | sti    | ruby~https://github.com/zhaozhanqi/ruby-docker-test/#isolation | sourceStrategy | # @case_id OCP-15734

  # @author zzhao@redhat.com
  # @bug_id 1487652
  @inactive
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario Outline: Build-container is constrained to access other projects pod for networkpolicy plugin
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `service("test-service").ip(user: user)` is stored in the :p1svcip clipboard
    And evaluation of `service("test-service").ports(user: user)[0].dig("port")` is stored in the :p1svcport clipboard

    Given I switch to the second user
    And I have a project
    When I run the :new_app client command with:
      | app_repo | <repo> |
    Then the step should succeed
    And the "ruby-docker-test-1" build was created
    When I run the :delete client command with:
      | object_type       | build         |
      | object_name_or_id | ruby-docker-test-1 |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | bc |
      | resource_name | ruby-docker-test |
      | p             | {"spec": {"strategy": {"<strategy>": {"env": [{"name": "SVC_IP","value": "<%= cb.p1svcip %>:<%= cb.p1svcport %>"}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-docker-test |
    Then the step should succeed
    And the "ruby-docker-test-2" build was created
    And I wait up to 400 seconds for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name | build/ruby-docker-test-2 |
    Then the output should contain "Hello OpenShift"
    """

    Given I switch to the first user
    #Create deny policy for project
    Given I obtain test data file "networking/networkpolicy/defaultdeny-v1-semantic.yaml"
    When I run the :create client command with:
      | f | defaultdeny-v1-semantic.yaml |
    Then the step should succeed

    Given I switch to the second user
    When I run the :delete client command with:
      | object_type       | build         |
      | object_name_or_id | ruby-docker-test-2 |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-docker-test |
    Then the step should succeed
    And the "ruby-docker-test-3" build was created
    And I wait up to 400 seconds for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name | build/ruby-docker-test-3 |
    Then the output should not contain "Hello OpenShift"
    Then the output should contain "Connection timed out after"
    """

    Examples:
      | type   | repo                                                           | strategy       |
      | Docker | https://github.com/zhaozhanqi/ruby-docker-test/#isolation      | dockerStrategy | # @case_id OCP-15731
      | sti    | ruby~https://github.com/zhaozhanqi/ruby-docker-test/#isolation | sourceStrategy | # @case_id OCP-15744

