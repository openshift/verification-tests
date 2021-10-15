Feature: ipv6 dual stack cluster test scenarios

  # @author zzhao@redhat.com
  # @case_id OCP-40581
  @admin
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
  Scenario: Project should be in isolation when using multitenant policy for ipv6 dual stack
    # create project and pods
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/list_for_pods_ipv6.json"
    When I run the :create client command with:
      | f | list_for_pods_ipv6.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).ip_v4` is stored in the :p1pod1ipv4 clipboard
    And evaluation of `pod(0).ip_v6_url` is stored in the :p1pod1ipv6_url clipboard
    Given I use the "test-service" service
    And evaluation of `service.ip_v4_url` is stored in the :service_ipv4_url clipboard
    And evaluation of `service.ip_v6_url` is stored in the :service_ipv6_url clipboard

    # create another project and pods
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I obtain test data file "networking/list_for_pods_ipv6.json"
    When I run the :create client command with:
      | f | list_for_pods_ipv6.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :p2pod1 clipboard

    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 10 | <%= cb.p1pod1ipv4 %>:<%= service.ports[0]["targetPort"] %> |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 10 | <%= cb.p1pod1ipv6_url %>:<%= service.ports[0]["targetPort"] %> |
    Then the step should succeed
    And the output should contain "Hello"

    #access pod by service ipv4 and ipv6 address
    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 10 | <%= cb.service_ipv4_url %> |
    Then the step should succeed
    And the output should contain "Hello"

    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 10 | <%= cb.service_ipv6_url %> |
    Then the step should succeed
    And the output should contain "Hello"


    #create multitetant policy in project 1
    Given I obtain test data file "networking/networkpolicy/multitenant_policy.yaml"
    When I run the :create admin command with:
      | f | multitenant_policy.yaml |
      | n | <%= cb.proj1 %>         |
    Then the step should succeed


    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.p1pod1ipv4 %>:<%= service.ports[0]["targetPort"] %> |
    Then the step should fail
    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.p1pod1ipv6_url %>:<%= service.ports[0]["targetPort"] %> |
    Then the step should fail

    #access pod by service ipv4 and ipv6 address
    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.service_ipv4_url %> |
    Then the step should fail

    When I execute on the "<%= cb.p2pod1 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.service_ipv6_url %> |
    Then the step should fail


