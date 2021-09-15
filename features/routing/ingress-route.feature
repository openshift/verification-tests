Feature: Testing ingress to route object

  # @author zzhao@redhat.com
  # @case_id OCP-18789
  @gcp-upi
  @gcp-ipi
  Scenario: Ingress generic support
    Given the master version >= "3.10"
    Given I have a project
    And I store an available router IP in the :router_ip clipboard
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    And the pod named "web-server-1" becomes ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    Given I obtain test data file "routing/ingress/test-ingress.json"
    When I run the :create client command with:
      | f | test-ingress.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | ingress      |
      | resource_name | test-ingress |
    Then the step should succeed
    And the output should contain "foo.bar.com"

    Given I have a pod-for-ping in the project
    When I execute on the "hello-pod" pod:
      | curl |
      | --resolve |
      | foo.bar.com:80:<%= cb.router_ip[0] %> |
      | http://foo.bar.com/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-1"
    When I execute on the "hello-pod" pod:
      | curl |
      | --resolve |
      | foo.bar.com:80:<%= cb.router_ip[0] %> |
      | http://foo.bar.com/test/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift-Path-Test"

