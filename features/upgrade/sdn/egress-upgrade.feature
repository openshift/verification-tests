Feature: Egress compoment upgrade testing

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Check egressfirewall is functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I run the :new_project client command with:
      | project_name | egressfw-upgrade1 |
    Then the step should succeed
    When I use the "egressfw-upgrade1" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:  
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | www.test.com | 
    Then the step should succeed
    And the output should contain "HTTP/1.1"

    Given I save egress data file directory to the clipboard
    Given I obtain test data file "networking/<%= cb.cb_egress_directory %>/limit_policy.json"
    When I run the :create admin command with:
      | f | limit_policy.json   |
      | n | <%= project.name %> |
    Then the step should succeed

    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | www.test.com |
    Then the step should fail 
    And the output should not contain "HTTP/1.1"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-44315
  @admin
  @upgrade-check
  @4.9
  @aws-upi
  Scenario: Check egressfirewall is functional post upgrade
    Given I switch to cluster admin pseudo user
    And I use the "egressfw-upgrade1" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | www.test.com |
    Then the step should fail 
    And the output should not contain "HTTP/1.1"

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Check ovn egressip is functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I save ipecho url to the clipboard
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard
    When I run the :label admin command with:
      | resource | node                               |
      | name     | <%= cb.egress_node %>              |
      | key_val  | k8s.ovn.org/egress-assignable=true |
    Then the step should succeed

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create new namespace and pods in it
    When I run the :new_project client command with:
      | project_name | egressip-upgrade1 |
    Then the step should succeed
    When I use the "egressip-upgrade1" project
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | egressip-upgrade1   |
      | key_val  | org=qe              |
    Then the step should succeed

    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    # Check source ip is egress ip
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-44316
  @admin
  @upgrade-check
  @4.9
  Scenario: Check ovn egressip is functional post upgrade
    Given I save ipecho url to the clipboard
    Given I switch to cluster admin pseudo user
    When I use the "egressip-upgrade1" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I run the :get admin command with:
      | resource       | egressip                    |
      | resource_name  | egressip                    |
      | o              | jsonpath={.status.items[*]} |
    Then the step should succeed
    And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)` is stored in the :valid_ip clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed 
    And the output should contain "<%= cb.valid_ip %>"

    # Remove label from egressip node and delete egress ip object
    Given admin ensures "egressip" egress_ip is deleted after scenario
    When I run the :get admin command with:
      | resource       | node                               |
      | l              | k8s.ovn.org/egress-assignable      |
      | o              | jsonpath={.items[*].metadata.name} |
    And evaluation of `@result[:response].chomp` is stored in the :egress_node clipboard
    When I run the :label admin command with:
      | resource | node                               |   
      | name     | <%= cb.egress_node %>              |   
      | key_val  | k8s.ovn.org/egress-assignable-     |
    Then the step should succeed
