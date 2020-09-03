Feature: OVNKubernetes Windows Container related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-26360
  @admin
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
    # Run level needs to set to 1 for windows pod to be spawned in a test project
    When I run the :label admin command with:
      | resource | namespace                |
      | name     | <%= project.name %>      |
      | key_val  | openshift.io/run-level=1 |
    Then the step should succeed
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
