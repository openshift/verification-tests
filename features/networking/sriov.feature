Feature: Sriov related scenarios

  # @author zzhao@redhat.com
  # @case_id OCP-29944
  @admin
  Scenario: sriov operator can be setup and running well
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sriov-network-operator" project
    And all existing pods are ready with labels:
      | app=network-resources-injector  |
    And all existing pods are ready with labels:
      | app=operator-webhook            |
    And all existing pods are ready with labels:
      | app=sriov-network-config-daemon |
    And status becomes :running of exactly 1 pods labeled:
      | name=sriov-network-operator     |


  # @author zzhao@redhat.com
  # @case_id OCP-24702
  @destructive
  @admin
  Scenario: netdevice VF for XXV710 can be worked well when sriovnetworknodepolicies is created for rhcos node
    Given the sriov operator is running well
    Given I obtain test data file "networking/sriov/sriovnetworkpolicy/intel-netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intel-netdevice.yaml     |
       | cr_name       | intel-netdevice          |
       | resource_type | sriovnetworknodepolicies |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource    | sriovnetworknodestates           |
      | namespace   | openshift-sriov-network-operator |
      | o           | yaml                             |
    Then the step should succeed
    And the output should contain "vfID: 4"
    """
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/static-sriovnetwork.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | static-sriovnetwork.yaml |
       | cr_name       | static-sriovnetwork      |
       | resource_type | sriovnetwork             |
       | project       | <%= cb.usr_project%>     |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project%>  |
    Then the step should succeed
    And the output should contain "static-sriovnetwork"
    """ 
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    Given I obtain test data file "networking/sriov/pod/sriov-without-resource-static.yaml"
    When I run the :create client command with:
      | f | sriov-without-resource-static.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=sriov-static |
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip addr show net1 |
    Then the output should contain "192.168.2.206"
    And the output should contain "2001::2/64"

