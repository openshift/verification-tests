Feature: Service related networking scenarios

  # @author yadu@redhat.com
  # @case_id OCP-9604
  @admin
  Scenario: tenants can access their own services
    # create pod and service in project1
    Given the env is using multitenant network
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    Given I use the "test-service" service
    And evaluation of `service.ip(user: user)` is stored in the :service1_ip clipboard
    Given I wait for the "test-service" service to become ready

    # create pod and service in project2
    Given I switch to the second user
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    Given I use the "test-service" service
    And evaluation of `service.ip(user: user)` is stored in the :service2_ip clipboard

    # access service in project2
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | -k | <%= cb.service2_ip %>:27017 |
    Then the output should contain:
      | Hello OpenShift |

    # access service in project1
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 4 | <%= cb.service1_ip %>:27017 |
    Then the step should fail
    Then the output should not contain:
      | Hello OpenShift |

  # @author yadu@redhat.com
  # @case_id OCP-9977
  @admin
  @destructive
  Scenario: Create service with external IP
    Given master config is merged with the following hash:
    """
    networkConfig:
      externalIPNetworkCIDRs:
      - 10.5.0.0/24
    """
    And the master service is restarted on all master nodes
    Given I have a project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json  |
    Then the step should succeed
    """
    And the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/externalip_service1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | service          |
      | resource_name | service-unsecure |
    Then the step should succeed
    And the output should contain:
      | 10.5.0.1 |
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 4 | 10.5.0.1:27017 |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift |

  # @author yadu@redhat.com
  # @case_id OCP-15032
  @admin
  Scenario: The openflow list will be cleaned after delete the services
    Given the env is using one of the listed network plugins:
      | subnet      |
      | multitenant |
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given I use the "service-unsecure" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
    Given I select a random node's host
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should contain:
      | <%= cb.service_ip %> |
    When I run the :delete client command with:
      | object_type       | svc              |
      | object_name_or_id | service-unsecure |
    Then the step should succeed
    Given I select a random node's host
    When I run ovs dump flows commands on the host
    Then the step should succeed
    And the output should not contain:
      | <%= cb.service_ip %> |

  # @auther anusaxen@redhat.com
  # @case_id OCP-23895
  @admin
  Scenario: User cannot access the MCS by creating a LoadBalancer service that points to the MCS
    Given I select a random node's host
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    And I have a pod-for-ping in the project
    #Creating laodbalancer service that points to MCS IP
    When I run the :create_service_loadbalancer client command with: 
      | name | hello-pod  |
      | tcp  | 22623:8080 | 
    Then the step should succeed
    #Getting loadbalancer service IP
    When I run the :get admin command with:
      | resource | svc                                 |
      | output   | jsonpath={.items[*].spec.clusterIP} |
      | n        | <%= project.name %>                 |
    And evaluation of `@result[:response].strip` is stored in the :svc_lb_ip clipboard
    #Make sure user cannot access the MCS by creating a LoadBalancer service that points to the MCS 
    When I execute on the pod:
      | curl | -I | http://<%= cb.svc_lb_ip %>:22623/config/master | -k |
    Then the output should contain "Connection refused"
