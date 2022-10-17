Feature: ipv6 dual stack cluster test scenarios

  # @author zzhao@redhat.com
  # @case_id OCP-40581
  @admin
  @network-ovnkubernetes
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @upgrade-sanity
  @proxy @noproxy @disconnected @connected
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @heterogeneous @arm64 @amd64
  Scenario: OCP-40581:SDN Project should be in isolation when using multitenant policy for ipv6 dual stack
    # create project and pods
    Given the cluster is dual stack network type
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


  # @author zzhao@redhat.com
  # @case_id OCP-46816
  @admin
  @network-ovnkubernetes
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @heterogeneous @arm64 @amd64
  Scenario: OCP-46816:SDN ipv6 for nodeport service
    Given the cluster is dual stack network type
    Given I store the workers in the :workers clipboard
    And the Internal IP of node "<%= cb.workers[1].name %>" is stored in the :worker1_ipv4 clipboard    
    And the Internal IPv6 of node "<%= cb.workers[0].name %>" is stored in the :worker0_ipv6 clipboard
    Given I have a project
    And evaluation of `rand(30000..31000)` is stored in the :port clipboard
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"] | <%= cb.port %> |
      | ["spec"]["ipFamilyPolicy"] | "RequireDualStack" |
    Then the step should succeed
    Given I use the "<%= cb.workers[0].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.worker1_ipv4 %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.worker0_ipv6 %>]:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 [<%= cb.worker0_ipv6 %>]:<%= cb.port %> |
    Then the step should fail
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.worker1_ipv4 %>:<%= cb.port %> |
    Then the step should fail
