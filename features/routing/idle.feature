Feature: idle service related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-10935
  @smoke
  Scenario: OCP-10935 Pod can be changed to un-idle when there is unsecure or edge or passthrough route coming
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/list_for_caddy.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given I wait until replicationController "caddy-rc" is ready
    And I wait until number of replicas match "1" for replicationController "caddy-rc"
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :idle client command with:
      | svc_name | service-unsecure |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "caddy-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Then I wait up to 60 seconds for a web server to become available via the "service-unsecure" route
    Given I wait until number of replicas match "1" for replicationController "caddy-rc"
    And a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

    # check edge route
    When I run the :create_route_edge client command with:
      | name | edge-route |
      | service | service-unsecure |
    Then the step should succeed
    When I run the :idle client command with:
      | svc_name | service-unsecure |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "caddy-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "edge-route" service
    Then I wait up to 60 seconds for a secure web server to become available via the "edge-route" route
    Given I wait until number of replicas match "1" for replicationController "caddy-rc"
    And a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

    # check passthrough route
    When I run the :create_route_passthrough client command with:
      | name    | route-pass     |
      | service | service-secure |
    Then the step should succeed
    When I run the :idle client command with:
      | svc_name | service-secure |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "caddy-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "route-pass" service
    Then I wait up to 60 seconds for a secure web server to become available via the "route-pass" route
    Given I wait until number of replicas match "1" for replicationController "caddy-rc"
    And a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

  # @author hongli@redhat.com
  # @case_id OCP-13837
  Scenario: OCP-13837 Pod can be changed to un-idle when there is reencrypt route coming
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/list_for_caddy.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given I wait until replicationController "caddy-rc" is ready
    And I wait until number of replicas match "1" for replicationController "caddy-rc"

    # check reencrypt route
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | route-reen              |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I run the :idle client command with:
      | svc_name | service-secure |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "caddy-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "route-reen" service
    Then I wait up to 60 seconds for a secure web server to become available via the "route-reen" route
    Given I wait until number of replicas match "1" for replicationController "caddy-rc"
    And a pod becomes ready with labels:
      | name=caddy-pods |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

