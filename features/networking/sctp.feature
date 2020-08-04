Feature: SCTP related scenarios

  # @author weliang@redhat.com
  # @case_id OCP-28757
  @admin
  @destructive
  Scenario: Establish pod to pod SCTP connections
    Given I store the workers in the :workers clipboard
    And I store the number of worker nodes to the :num_workers clipboard
    And the Internal IP of node "<%= cb.workers[1].name %>" is stored in the :worker1_ip clipboard
    
    Given I install machineconfigs load-sctp-module
    And I wait up to 800 seconds for the steps to pass:
    """
    Given I check load-sctp-module in <%= cb.num_workers %> workers
    """
    
    Given I have a project
    Given I obtain test data file "networking/sctp/sctpserver.yaml"
    When I run oc create as admin over "sctpserver.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[0].name %> |
    Then the step should succeed
    And the pod named "sctpserver" becomes ready
    Then evaluation of `pod.ip` is stored in the :serverpod_ip clipboard

    Given I obtain test data file "networking/sctp/sctpclient.yaml"
    When I run oc create as admin over "sctpclient.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[1].name %> |
    Then the step should succeed
    And the pod named "sctpclient" becomes ready
   
    # sctpserver pod start to wait for sctp traffic
    When I run the :exec background client command with:
      | pod              | sctpserver          |
      | namespace        | <%= project.name %> |
      | oc_opts_end      |                     |
      | exec_command     | sh                  |
      | exec_command_arg | -c                  |
      | exec_command_arg | nc -l 30102 --sctp  |     
    Then the step should succeed

    # sctpclient pod start to send sctp traffic
    When I run the :exec client command with:
      | pod              | sctpclient                                                       |
      | namespace        | <%= project.name %>                                              |
      | oc_opts_end      |                                                                  |
      | exec_command     | sh                                                               |
      | exec_command_arg | -c                                                               |
      | exec_command_arg | echo test-openshift \| nc -v <%= cb.serverpod_ip %> 30102 --sctp | 
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.serverpod_ip %>:30102 |
      | 15 bytes sent                             |