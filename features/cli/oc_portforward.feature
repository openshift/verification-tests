Feature: oc_portforward.feature

  # @author pruan@redhat.com
  # @case_id OCP-11195
  Scenario: OCP-11195 Forward multi local ports to a pod
    Given I have a project
    And evaluation of `rand(5000..7999)` is stored in the :porta clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portb clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portc clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portd clipboard
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Given the pod named "doublecontainers" status becomes :running
    And I run the :port_forward background client command with:
      | pod | doublecontainers |
      | port_spec | <%= cb[:porta] %>:8080  |
      | port_spec | <%= cb[:portb] %>:8081  |
      | port_spec | <%= cb[:portc] %>:8080  |
      | port_spec | <%= cb[:portd] %>:8081  |
      | _timeout | 40 |
    Then the step should succeed
    And I wait up to 40 seconds for the steps to pass:
    """
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:porta] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portb] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portc] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portd] %>
      :method: :get
      <%= '"""' %>
    """

