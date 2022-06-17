Feature: Testing abrouting

  # @author yadu@redhat.com
  # @case_id OCP-12076
  Scenario: OCP-12076 Set backends weight for unsecure route
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/unseucre/service_unsecure.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/unseucre/service_unsecure-2.json |
    Then the step should succeed
    Given I wait for the "service-unsecure" service to become ready
    Given I wait for the "service-unsecure-2" service to become ready
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                          |
      | resourcename | service-unsecure                               |
      | overwrite    | true                                           |
      | keyval       | haproxy.router.openshift.io/balance=roundrobin |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | service   | service-unsecure=20   |
      | service   | service-unsecure-2=80 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
    Then the step should succeed
    Then the output should contain 1 times:
      | (20%) |
      | (80%) |
    Given the "access.log" file is deleted if it exists
    When I wait up to 20 seconds for a web server to become available via the "service-unsecure" route
    And I run the steps 40 times:
    """
    When I open web server via the "service-unsecure" route
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the "access.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength2 clipboard
    Then the expression should be true> (28..36).include? cb.accesslength2
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength1 clipboard
    Then the expression should be true> (4..12).include? cb.accesslength1
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | adjust    | true                  |
      | service   | service-unsecure=-10% |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
    Then the step should succeed
    Then the output should contain 1 times:
      | (10%) |
      | (90%) |
    Given the "access1.log" file is deleted if it exists
    When I wait up to 20 seconds for a web server to become available via the "service-unsecure" route
    And I run the steps 40 times:
    """
    When I open web server via the "service-unsecure" route
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the "access1.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access1.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength4 clipboard
    Then the expression should be true> (32..39).include? cb.accesslength4
    Given evaluation of `File.read("access1.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength3 clipboard
    Then the expression should be true> (1..8).include? cb.accesslength3

  # @author yadu@redhat.com
  # @case_id OCP-11970
  Scenario: OCP-11970 Set backends weight for reencrypt route
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/caddy-docker.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/caddy-docker-2.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/reencrypt/service_secure.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/reencrypt/service_secure-2.json |
    Then the step should succeed
    Given I wait for the "service-secure" service to become ready
    Given I wait for the "service-secure-2" service to become ready
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/example_wildcard.pem"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/example_wildcard.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.ca"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    When I run the :create_route_reencrypt client command with:
      | name | route-reencrypt |
      | hostname | <%= rand_str(5, :dns) %>-reen.example.com |
      | service | service-secure |
      | cert | example_wildcard.pem |
      | key | example_wildcard.key |
      | cacert | route_reencrypt.ca |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource     | route                                          |
      | resourcename | route-reencrypt                                |
      | overwrite    | true                                           |
      | keyval       | haproxy.router.openshift.io/balance=roundrobin |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-reencrypt     |
      | service   | service-secure=3    |
      | service   | service-secure-2=7  |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-reencrypt |
    Then the step should succeed
    Then the output should contain 1 times:
      | (30%) |
      | (70%) |
    Given I have a pod-for-ping in the project
    And CA trust is added to the pod-for-ping
    Given the "access.log" file is deleted if it exists
    And I run the steps 20 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | --resolve |
      | <%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the "access.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength2 clipboard
    Then the expression should be true> (13..15).include? cb.accesslength2
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength1 clipboard
    Then the expression should be true> (5..7).include? cb.accesslength1
    When I run the :set_backends client command with:
      | routename | route-reencrypt        |
      | adjust    | true                   |
      | service   | service-secure=-20%  |
    When I run the :set_backends client command with:
      | routename | route-reencrypt |
    Then the step should succeed
    Then the output should contain 1 times:
      | (10%) |
      | (90%) |
    Then the step should succeed
    Given the "access1.log" file is deleted if it exists
    Given I run the steps 20 times:
    """
    When I execute on the pod:
      | curl |
      | -sS |
      | --resolve |
      | <%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-reencrypt", service("route-reencrypt")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the step should succeed
    And the output should contain "Hello-OpenShift"

    And the "access1.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access1.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength4 clipboard
    Then the expression should be true> (17..19).include? cb.accesslength4
    Given evaluation of `File.read("access1.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength3 clipboard
    Then the expression should be true> (1..3).include? cb.accesslength3

  # @author yadu@redhat.com
  # @case_id OCP-13519
  @admin
  Scenario: OCP-13519 The edge route with multiple service will set load balance policy to RoundRobin by default
    #Create pod/service/route
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/unseucre/service_unsecure.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/unseucre/service_unsecure-2.json |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name    | edge1            |
      | service | service-unsecure |
    Then the step should succeed
    #Check the default load blance policy
    Given I switch to cluster admin pseudo user
    And I use the router project
    And all default router pods become ready
    Then evaluation of `pod.name` is stored in the :router_pod clipboard
    And I wait up to 5 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """
    #Add multiple services to route
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=1   |
      | service   | service-unsecure-2=9 |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I wait up to 5 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "roundrobin"
    """
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=0   |
      | service   | service-unsecure-2=1 |
    Then the step should succeed
    #Set one of the service weight to 0
    Given I switch to cluster admin pseudo user
    And I wait up to 5 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """
    Given I switch to the first user
    When I run the :set_backends client command with:
      | routename | edge1                |
      | service   | service-unsecure=0   |
      | service   | service-unsecure-2=0 |
    Then the step should succeed
    #Set all the service weight to 0
    Given I switch to cluster admin pseudo user
    And I wait up to 5 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep             |
      | edge1            |
      | -A               |
      | 10               |
      | haproxy.config   |
    Then the output should contain "leastconn"
    """

  # @author yadu@redhat.com
  # @case_id OCP-15910
  Scenario: OCP-15910 Each endpoint gets weight/numberOfEndpoints portion of the requests - unsecure route
    # Create pods and services
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod1.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod2.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod3.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod4.json |
    Then the step should succeed
    Given I wait for the "service-unsecure" service to become ready
    Given I wait for the "service-unsecure-2" service to become ready
    Given I wait for the "service-unsecure-3" service to become ready
    Given I wait for the "service-unsecure-4" service to become ready
    # Create route and set route backends
    When I expose the "service-unsecure" service
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure      |
      | service   | service-unsecure=20   |
      | service   | service-unsecure-2=10 |
      | service   | service-unsecure-3=30 |
      | service   | service-unsecure-4=40 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | service-unsecure  |
    Then the step should succeed
    Then the output should contain:
      | 20% |
      | 10% |
      | 30% |
      | 40% |
    # Scale pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-1              |
      | replicas | 2                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-2              |
      | replicas | 4                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-3              |
      | replicas | 3                      |
    Then the step should succeed
    And all pods in the project are ready
    # Access the route
    Given the "access.log" file is deleted if it exists
    When I wait up to 20 seconds for a web server to become available via the "service-unsecure" route
    And I run the steps 20 times:
    """
    When I open web server via the "service-unsecure" route
    And the output should contain "Hello-OpenShift"
    And the "access.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-4").size` is stored in the :accesslength4 clipboard
    Then the expression should be true> (6..10).include? cb.accesslength4
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-3").size` is stored in the :accesslength3 clipboard
    Then the expression should be true> (4..8).include? cb.accesslength3
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength2 clipboard
    Then the expression should be true> (1..3).include? cb.accesslength2
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength1 clipboard
    Then the expression should be true> (2..6).include? cb.accesslength1

  # @author yadu@redhat.com
  # @case_id OCP-15994
  Scenario: OCP-15994 Each endpoint gets weight/numberOfEndpoints portion of the requests - passthrough route
    # Create pods and services
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod1.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod2.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod3.json |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/abrouting/abwithrc_pod4.json |
    Then the step should succeed
    Given I wait for the "service-secure" service to become ready
    Given I wait for the "service-secure-2" service to become ready
    Given I wait for the "service-secure-3" service to become ready
    Given I wait for the "service-secure-4" service to become ready
    # Create route and set route backends
    When I run the :create_route_passthrough client command with:
      | name    | route-pass     |
      | service | service-secure |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-pass            |
      | service   | service-secure=20   |
      | service   | service-secure-2=10 |
      | service   | service-secure-3=30 |
      | service   | service-secure-4=40 |
    Then the step should succeed
    When I run the :set_backends client command with:
      | routename | route-pass            |
    Then the step should succeed
    Then the output should contain:
      | 20% |
      | 10% |
      | 30% |
      | 40% |
    # Scale pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-1              |
      | replicas | 2                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-2              |
      | replicas | 4                      |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc-3              |
      | replicas | 3                      |
    Then the step should succeed
    And all pods in the project are ready
    # Access the route
    When I use the "service-secure" service
    Given the "access.log" file is deleted if it exists
    When I wait up to 20 seconds for a secure web server to become available via the "route-pass" route
    And I run the steps 20 times:
    """
    When I open secure web server via the "route-pass" route
    Then the step should succeed
    And the output should contain "Hello-OpenShift"
    And the "access.log" file is appended with the following lines:
      | #{@result[:response].strip} |
    """
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-4").size` is stored in the :accesslength4 clipboard
    Then the expression should be true> (6..10).include? cb.accesslength4
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-3").size` is stored in the :accesslength3 clipboard
    Then the expression should be true> (4..8).include? cb.accesslength3
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-2").size` is stored in the :accesslength2 clipboard
    Then the expression should be true> (1..3).include? cb.accesslength2
    Given evaluation of `File.read("access.log").scan("Hello-OpenShift-1").size` is stored in the :accesslength1 clipboard
    Then the expression should be true> (2..6).include? cb.accesslength1

