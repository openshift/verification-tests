Feature: Testing ingress to route object

  # @author zzhao@redhat.com
  # @case_id OCP-18789
  Scenario: OCP-18789 Ingress generic support 
    Given the master version >= "3.10"
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ingress/test-ingress.json" replacing paths:
      | ["spec"]["rules"][0]["http"]["paths"][0]["backend"]["servicePort"] | 27017 |
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
    And the output should contain "Hello-OpenShift-1"
    When I execute on the "hello-pod" pod:
      | curl |
      | --resolve |
      | foo.bar.com:80:<%= cb.router_ip[0] %> |
      | http://foo.bar.com/test/ |
    Then the step should succeed
    And the output should contain "Hello-OpenShift-Path-Test"

