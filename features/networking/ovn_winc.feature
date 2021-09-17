Feature: OVNKubernetes Windows Container related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-26360
  @admin
  @4.9
  Scenario: Ensure Pods and Service communication across window and linux nodes
    Given the env has hybridOverlayConfig enabled
    And the env is using windows nodes
    Given I have a project
    And I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod` is stored in the :linux_pod clipboard

    Given I use the "test-service" service
    And evaluation of `service.ip` is stored in the :linux_service_ip clipboard

    Given I obtain test data file "networking/windows_pod_and_service.yaml"
    When I run the :create client command with:
      | f | windows_pod_and_service.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=win-webserver |
    And evaluation of `pod` is stored in the :windows_pod clipboard

    Given I use the "win-service" service
    And evaluation of `service.ip` is stored in the :windows_service_ip clipboard
    #Checking Service communication across pods
    When I execute on the "<%= cb.linux_pod.name %>" pod:
      | curl | -s | --connect-timeout | 2 | <%= cb.windows_service_ip %>:27018 |
    Then the step should succeed
    And the output should contain "Windows Container Web Server"

    When I execute on the "<%= cb.windows_pod.name %>" pod:
      | curl | -s | --connect-timeout | 2 | <%= cb.linux_service_ip %>:27017 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"

    #Checking network communication across pods
    When I execute on the "<%= cb.linux_pod.name %>" pod:
      | curl | -s | --connect-timeout | 2 | <%= cb.windows_pod.ip %>:80 |
    Then the step should succeed
    And the output should contain "Windows Container Web Server"

    When I execute on the "<%= cb.windows_pod.name %>" pod:
      | curl | -s | --connect-timeout | 2 | <%= cb.linux_pod.ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"

  # @author anusaxen@redhat.com
  # @case_id OCP-37519
  @admin
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Create Loadbalancer service for a window container
    Given the env has hybridOverlayConfig enabled
    And the env is using windows nodes
    Given I have a project
    And I have a pod-for-ping in the project
    Given I obtain test data file "networking/windows_pod_and_service.yaml"
    When I run the :create client command with:
      | f | windows_pod_and_service.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=win-webserver |

    # Create loadbalancer service
    When I run the :create_service_loadbalancer client command with:
      | name | win-webserver |
      | tcp  | 80            |
    Then the step should succeed

    # Get the external ip of the loadbalancer service
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | svc                                        |
      | resource_name | win-webserver                              |
      | template      | {{(index .status.loadBalancer.ingress 0)}} |
    Then the step should succeed
    """
    And evaluation of `@result[:response].match(/:(.*)]/)[1]` is stored in the :service_external_ip clipboard

    # check the external:ip of loadbalancer can be accessed
    When I execute on the "hello-pod" pod:
      | curl | -s | --connect-timeout | 10 | <%= cb.service_external_ip %> |
    Then the step should succeed
    And the output should contain "Windows Container Web Server"
