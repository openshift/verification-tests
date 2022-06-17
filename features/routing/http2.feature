Feature: Testing HTTP/2 related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-19705
  @admin
  @destructive
  Scenario: OCP-19705 edge route support http2 protocol
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_ENABLE_HTTP2=true |

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/httpbin-pod.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=httpbin-pod |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/unsecure/service_unsecure.json  |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name       | edge-route       |
      | service    | service-unsecure |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl |
      | --http2 |
      | -v |
      | -k |
      | https://<%= route("edge-route", service("service-unsecure")).dns(by: user) %>/headers |
    Then the step should succeed
    And the output should match:
      | "Forwarded":.*proto-version=h2         |
      | "X-Forwarded-Proto-Version": "h2"      |
      | ALPN, server accepted to use h2        |
      | Using HTTP2, server supports multi-use |
      | HTTP/2 200                             |

  # @author hongli@redhat.com
  # @case_id OCP-19706
  @admin
  @destructive
  Scenario: OCP-19706 reencrypt route support http2 protocol
    Given the master version >= "3.11"
    Given I switch to cluster admin pseudo user
    And I use the router project
    Given admin ensures new router pod becomes ready after following env added:
      | ROUTER_ENABLE_HTTP2=true |

    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/httpbin-pod.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=httpbin-pod |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/routetimeout/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name       | reen-route              |
      | service    | service-secure          |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl |
      | --http2 |
      | -v |
      | -k |
      | https://<%= route("reen-route", service("service-secure")).dns(by: user) %>/headers |
    Then the step should succeed
    And the output should match:
      | "Forwarded":.*proto-version=h2         |
      | "X-Forwarded-Proto-Version": "h2"      |
      | ALPN, server accepted to use h2        |
      | Using HTTP2, server supports multi-use |
      | HTTP/2 200                             |

