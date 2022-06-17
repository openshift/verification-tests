Feature: Testing websocket features

  # @author hongli@redhat.com
  # @case_id OCP-17145
  Scenario: OCP-17145 haproxy router support websocket via unsecure route
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/websocket/pod.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/websocket/service_unsecure.json |
    Then the step should succeed
    When I expose the "ws-unsecure" service
    Then the step should succeed

    Given I have a pod-for-ping in the project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash | -c | (echo WebsocketTesting ; sleep 3) \| ws ws://<%= route("ws-unsecure", service("ws-unsecure")).dns(by: user) %>/echo |
    Then the step should succeed
    And the output should contain "< WebsocketTesting"
    """

