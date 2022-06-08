Feature: idle service related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-10935
  Scenario: OCP-10935 Pod can be changed to un-idle when there is unsecure or edge or passthrough route coming
    Given I have a project
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run the :create client command with:
      | f | web-server-rc.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.name` is stored in the :pod_name clipboard
    When I expose the "service-unsecure" service
    Then the step should succeed
    And I wait up to 60 seconds for a web server to become available via the "service-unsecure" route

    # ilde the service then wake up
    When I run the :idle client command with:
      | svc_name | service-unsecure |
    Then the step should succeed
    Given I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear within 120 seconds
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Then I wait up to 60 seconds for a web server to become available via the "service-unsecure" route
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    And evaluation of `pod.name` is stored in the :pod_name clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

    # check edge route
    When I run the :create_route_edge client command with:
      | name    | edge-route       |
      | service | service-unsecure |
    Then the step should succeed
    And I wait up to 60 seconds for a secure web server to become available via the "edge-route" route
    When I run the :idle client command with:
      | svc_name | service-unsecure |
    Then the step should succeed
    Given I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear within 120 seconds
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "edge-route" service
    Then I wait up to 60 seconds for a secure web server to become available via the "edge-route" route
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    And evaluation of `pod.name` is stored in the :pod_name clipboard
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
    Then I wait up to 60 seconds for a secure web server to become available via the "route-pass" route
    When I run the :idle client command with:
      | svc_name | service-secure |
    Then the step should succeed
    Given I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear within 120 seconds
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "route-pass" service
    Then I wait up to 60 seconds for a secure web server to become available via the "route-pass" route
    And a pod becomes ready with labels:
      | name=web-server-rc |
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
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run the :create client command with:
      | f | web-server-rc.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.name` is stored in the :pod_name clipboard

    # check reencrypt route
    Given I obtain test data file "routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | route-reen              |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    And I wait up to 60 seconds for a secure web server to become available via the "route-reen" route
    When I run the :idle client command with:
      | svc_name | service-secure |
    Then the step should succeed
    Given I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear within 120 seconds
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*none |
      | service-unsecure.*none |
    Given I use the "route-reen" service
    Then I wait up to 60 seconds for a secure web server to become available via the "route-reen" route
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | service-secure.*<%= cb.pod_ip %>:8443 |
      | service-unsecure.*<%= cb.pod_ip %>:8080 |

