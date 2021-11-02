Feature: Testing websocket features

  # @author hongli@redhat.com
  # @case_id OCP-17145
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: haproxy router support websocket via unsecure route
    Given I have a project
    Given I obtain test data file "routing/websocket/pod.json"
    When I run the :create client command with:
      | f | pod.json |
    Then the step should succeed
    Given I obtain test data file "routing/websocket/service_unsecure.json"
    When I run the :create client command with:
      | f | service_unsecure.json |
    Then the step should succeed
    When I expose the "ws-unsecure" service
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash | -c | (echo WebsocketTesting ; sleep 20) \| ws ws://<%= route("ws-unsecure", service("ws-unsecure")).dns(by: user) %>/echo |
    Then the step should succeed
    And the output should contain "< WebsocketTesting"
    """

