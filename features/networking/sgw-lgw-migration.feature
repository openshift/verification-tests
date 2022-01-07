Feature: SGW<->LGW migration related scenarios
  
  # @author anusaxen@redhat.com
  # @case_id OCP-47561
  @4.10
  @admin
  @destructive
  @network-ovnkubernetes
  @vsphere-ipi @baremetal-ipi
    Scenario: [SDN-2290] SGW <-> LGW migration scenario	
    ######## Prepare Data Pre Migration for multiple use cases############
    Given the env is using "OVNKubernetes" networkType
    
    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master0_ip clipboard
    And evaluation of `rand(30000..32767)` is stored in the :port clipboard
    Given I have a project
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod.node_ip` is stored in the :hostip clipboard
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"]  | <%= cb.port %> |
      | ["spec"]["externalTrafficPolicy"] | Local          |
    Then the step should succeed
    
    #Switching cluster to another gateway mode and reverting back to original in clean up
    Given I switch the ovn gateway mode on this cluster
    And I register clean-up steps:
    """
    I switch the ovn gateway mode on this cluster
    """
    
    ######## Check Data Post Migration for multiple use cases############
    
    
    #OCP-47087 - [bug_1903408]Other node cannot be accessed for nodePort when externalTrafficPolicy is Local	
    Given I use the "<%= cb.masters[1].name %>" node
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.hostip %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.master0_ip %>:<%= cb.port %> |
    Then the step should fail
    And the output should not contain:
      | Hello OpenShift! |
    Given I ensure "hello-pod" service is deleted
    When I run commands on the host:
      | curl --connect-timeout 5 <%= cb.hostip %>:<%= cb.port %> |
    Then the step should fail
