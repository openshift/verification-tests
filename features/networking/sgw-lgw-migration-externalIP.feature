Feature: SGW<->LGW migration related scenarios

  # @author weliang@redhat.com
  # @case_id OCP-48066
  @4.10
  @admin
  @destructive
  @network-ovnkubernetes
  @vsphere-ipi
  @baremetal-upi
  Scenario: [SDN-2290] SGW <-> LGW migration scenarios for externalIP	
    Given the env is using "OVNKubernetes" networkType

    ######## Prepare Data Pre Migration for multiple use cases############
    #OCP-24669 - externalIP defined in service with set ExternalIP in allowedCIDRs
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    Given I store the schedulable nodes in the :nodes clipboard
    And the Internal IP of node "<%= cb.nodes[0].name %>" is stored in the :hostip clipboard

    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["<%= cb.hostip %>/24"]}}}} |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs": null}}}} |
    """

    # Create a svc with externalIP
    Given I switch to the first user
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %> |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "networking/externalip_pod.yaml"
    When I run the :create client command with:
      | f | externalip_pod.yaml |
    Then the step should succeed
    And the pod named "externalip-pod" becomes ready
 
    # Curl externalIP:portnumber should pass
    Given I store the masters in the :masters clipboard
	  Given I use the "<%= cb.masters[0].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.masters[1].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

    # Switching cluster to another gateway mode and reverting back to original in clean up
    Given the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    And I switch the ovn gateway mode on this cluster
    And I register clean-up steps:
    """
    I switch the ovn gateway mode on this cluster
    And the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    """
    
    ######## Check Data Post Migration for multiple use cases############   
    #OCP-24669 - externalIP defined in service with set ExternalIP in allowedCIDRs
    Given I use the "<%= cb.masters[0].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
    Given I use the "<%= cb.masters[1].name %>" node
    And I run commands on the host:
      | /usr/bin/curl  --connect-timeout  10  <%= cb.hostip %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |