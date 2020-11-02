Feature: OVN Egress IP related features

  # @author huirwang@redhat.com
  # @case_id OCP-33618
  @admin
  @destructive
  Scenario: EgressIP works for all pods in the matched namespace when only configure namespaceSelector
    Given I save ipecho url to the clipboard
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard
    Then label "k8s.ovn.org/egress-assignable=true" is added to the "<%= cb.egress_node %>" node

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create new namespace and pods in it
    Given I have a project
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | <%= project.name %> |
      | key_val  | og=qe               |
    Then the step should succeed

    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard
    And evaluation of `pod(2).name` is stored in the :pod2 clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed
    And admin ensures "egressip" egress_ip is deleted after scenario

    # Create some more pods after the egressip object created
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 3                      |
    Then the step should succeed
    Given 3 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(3).name` is stored in the :pod3 clipboard

    # Check source ip is egress ip
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
