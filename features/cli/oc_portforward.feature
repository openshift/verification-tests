Feature: oc_portforward.feature

  # @author pruan@redhat.com
  # @case_id OCP-11195
  @admin
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  Scenario: Forward multi local ports to a pod
    Given I have a project
    And evaluation of `rand(5000..7999)` is stored in the :porta clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portb clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portc clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portd clipboard
    Given I obtain test data file "pods/pod_with_two_containers.json"
    And I run the :create client command with:
      | f | pod_with_two_containers.json |
    Given the pod named "doublecontainers" status becomes :running
    And I run the :port_forward background client command with:
      | pod | doublecontainers |
      | port_spec | <%= cb[:porta] %>:8080  |
      | port_spec | <%= cb[:portb] %>:8081  |
      | port_spec | <%= cb[:portc] %>:8080  |
      | port_spec | <%= cb[:portd] %>:8081  |
      | _timeout | 40 |
    Then the step should succeed
    Given the expression should be true> @host = localhost
    And I wait up to 40 seconds for the steps to pass:
    """
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:porta] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:portb] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:portc] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I run commands on the host:
      | curl http://127.0.0.1:<%= cb[:portd] %> --noproxy "127.0.0.1" |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    """
