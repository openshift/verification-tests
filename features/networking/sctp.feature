Feature: SCTP related scenarios

  # @author weliang@redhat.com
  # @case_id OCP-28757
  @admin
  @destructive
  Scenario: Establish pod to pod SCTP connections
    Given I store the ready and schedulable workers in the :workers clipboard
    And I install machineconfigs load-sctp-module
    And I have a project
    And I wait up to 800 seconds for the steps to pass:
    """
    Given I check load-sctp-module in all workers
    """

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
    When I execute on the "sctpserver" pod:
      | bash | -c  | nc -k -l 30102 --sctp |

    # sctpclient pod start to send sctp traffic
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.serverpod_ip %>:30102 |
      | 15 bytes sent                             |
    """

  # @author weliang@redhat.com
  # @case_id OCP-28758
  @admin
  @destructive
  Scenario: Expose SCTP ClusterIP Services
    Given I store the ready and schedulable workers in the :workers clipboard
    And I install machineconfigs load-sctp-module
    And I have a project
    And I wait up to 800 seconds for the steps to pass:
    """
    Given I check load-sctp-module in all workers
    """
 
    Given I obtain test data file "networking/sctp/sctpserver.yaml"
    When I run oc create as admin over "sctpserver.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[0].name %> |
    Then the step should succeed
    And the pod named "sctpserver" becomes ready

    Given I obtain test data file "networking/sctp/sctpclient.yaml"
    When I run oc create as admin over "sctpclient.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[1].name %> |
    Then the step should succeed
    And the pod named "sctpclient" becomes ready

    Given I obtain test data file "networking/sctp/sctpservice.yaml"
    When I run oc create as admin over "sctpservice.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
    Given I wait for the "sctpservice" service to become ready
    Given I use the "sctpservice" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard

    # sctpserver pod start to wait for sctp traffic
    When I execute on the "sctpserver" pod:
      | bash | -c  | nc -k -l 30102 --sctp |

    # sctpclient pod start to send sctp traffic
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.service_ip %> 30102 --sctp |
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.service_ip %>:30102 |
      | 15 bytes sent                           |
    """

  # @author weliang@redhat.com
  # @case_id OCP-28759
  @admin
  @destructive
  Scenario: Expose SCTP NodePort Services
    Given I store the ready and schedulable workers in the :workers clipboard
    And the Internal IP of node "<%= cb.workers[1].name %>" is stored in the :worker1_ip clipboard
    Given I install machineconfigs load-sctp-module
    Given I have a project
    And I wait up to 800 seconds for the steps to pass:
    """
    Given I check load-sctp-module in all workers
    """

    Given I obtain test data file "networking/sctp/sctpserver.yaml"
    When I run oc create as admin over "sctpserver.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[0].name %> |
    Then the step should succeed
    And the pod named "sctpserver" becomes ready

    Given I obtain test data file "networking/sctp/sctpclient.yaml"
    When I run oc create as admin over "sctpclient.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
      | ["spec"]["nodeName"]      | <%= cb.workers[1].name %> |
    Then the step should succeed
    And the pod named "sctpclient" becomes ready

    Given I obtain test data file "networking/sctp/sctpservice.yaml"
    When I run oc create as admin over "sctpservice.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>       |
    Given I wait for the "sctpservice" service to become ready
    Given I use the "sctpservice" service
    And evaluation of `service(cb.sctpserver).node_port(port:30102)` is stored in the :nodeport clipboard

    # sctpserver pod start to wait for sctp traffic
   When I execute on the "sctpserver" pod:
      | bash | -c  | nc -k -l 30102 --sctp |

    # sctpclient pod start to send sctp traffic on worknode:port
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.worker1_ip %> <%= cb.nodeport %>  --sctp |
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.worker1_ip %>:<%= cb.nodeport %> |
      | 15 bytes sent                                        |
    """

  # @author weliang@redhat.com
  # @case_id OCP-29645
  @admin
  @destructive
  Scenario: Networkpolicy allow SCTP Client
    Given I store the ready and schedulable workers in the :workers clipboard
    And I install machineconfigs load-sctp-module
    And I have a project
    And I wait up to 800 seconds for the steps to pass:
    """
    Given I check load-sctp-module in all workers
    """

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
     When I execute on the "sctpserver" pod:
      | bash | -c  | nc -k -l 30102 --sctp |

    # sctpclient pod start to send sctp traffic
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.serverpod_ip %> |
      | 15 bytes sent                       |
    """

    # Define a networkpolicy to deny sctpclient to sctpserver
    Given I obtain test data file "networking/sctp/default-deny.yaml"
    When I run the :create admin command with:
      | f | default-deny.yaml   |
      | n | <%= project.name %> |
    Then the step should succeed

    # sctpclient pod start to send sctp traffic
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should fail
    """

    # Define a networkpolicy to allow sctpclient to sctpserver
    Given I obtain test data file "networking/sctp/allow_sctpclient.yaml"
    When I run the :create admin command with:
      | f | allow_sctpclient.yaml |
      | n | <%= project.name %>   |
    Then the step should succeed

    # sctpserver pod start to wait for sctp traffic
     When I execute on the "sctpserver" pod:
      | bash | -c  | nc -k -l 30102 --sctp |
      
    # sctpclient pod start to send sctp traffic
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "sctpclient" pod:
      | bash | -c | echo test-openshift \| nc -w 5 -v <%= cb.serverpod_ip %> 30102 --sctp |
    Then the step should succeed
    And the output should contain:
      | Connected to <%= cb.serverpod_ip %> |
      | 15 bytes sent                       |
    """
