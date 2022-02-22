Feature: Secure Computing Test Scenarios

  # @author wmeng@redhat.com
  # @case_id OCP-10483
  @inactive
  Scenario: seccomp=unconfined used by default
    Given I have a project
    Given I obtain test data file "pods/hello-pod.json"
    When I run the :create client command with:
      | filename  | hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I execute on the pod:
      | grep | Seccomp | /proc/self/status |
    Then the output should contain:
      | 0 |
    And the output should not contain:
      | 2 |

  # @author jhou@redhat.com
  # @case_id OCP-32065
  @admin
  @destructive
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  Scenario: Using Secure Computing Profiles with Pod Annotations
    # Create custom machine config that contains the seccomp
    Given I switch to cluster admin pseudo user
    And I obtain test data file "node/machineconfig_nostat.yaml"
    When I run the :create admin command with:
      | f | machineconfig_nostat.yaml |
    Then the step should succeed
    And admin ensures "custom-seccomp" machineconfig is deleted after scenario

    # Wait for machineconfigpool to roll out the new machineconfig
    Given I wait up to 1200 seconds for the steps to pass:
    """
    Then the expression should be true> machine_config_pool('worker').raw_resource(cached: false).dig('status', 'configuration', 'source').select { |c| c['name'] == 'custom-seccomp' }.empty? == false
    Then the expression should be true> machine_config_pool('worker').condition(type: 'Updating', cached: false)["status"] == "False"
    """

    # Create a Pod with seccomp annotaiton
    And I use the "default" project
    Given I obtain test data file "node/pod_nostat.json"
    When I run the :create admin command with:
      | f | pod_nostat.json |
    Then the step should succeed
    And admin ensures "nostat" pod is deleted after scenario
    # Verify sure container can not run 'ls'
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource      | pod    |
      | resource_name | nostat |
    Then the output should contain "Error"
    """
    When I run the :logs admin command with:
      | resource_name | nostat  |
    Then the output should contain:
      | ls                      |
      | Operation not permitted |
