Feature: Testing ingress object

  # @author hongli@redhat.com
  # @case_id OCP-11069
  @admin
  @destructive
  Scenario: OCP-11069 haproxy support ingress object
    Given required cluster roles are added to router service account for ingress
    And admin ensures new router pod becomes ready after following env added:
      | ROUTER_ENABLE_INGRESS=true |

    Given I switch to the first user
    And I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given cluster role "cluster-admin" is added to the "first" user
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ingress/test-ingress.json |
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

