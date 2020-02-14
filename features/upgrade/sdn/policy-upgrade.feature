Feature: SDN compoment upgrade testing

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  Scenario: network operator should be available after upgrade - prepare
  # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
  # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
  # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author huirwang@redhat.com
  # @case_id OCP-22707
  @admin
  @upgrade-check
  Scenario: network operator should be available after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-network-operator" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=network-operator |
    # Check network operator version match cluster version
    And the "network" operator version matches the current cluster version
    # Check the operator object has status for Degraded|Progressing|Available|Upgradeable
    And the expression should be true> cluster_operator('network').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('network').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Upgradeable')['status'] == "True"


  # @author zzhao@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Check the networkpolicy works well after upgrade - prepare
    Given I switch to cluster admin pseudo user		
    When I run the :new_project client command with:
      | project_name | policy-upgrade |		
    Then the step should succeed
    When I use the "policy-upgrade" project      
    And I run the :create client command with:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/networking/list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should succeed 
    And the output should contain "Hello"    

    Given the DefaultDeny policy is applied to the "policy-upgrade" namespace
    Then the step should succeed

    When I use the "policy-upgrade" project
    Then I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    And the step should fail
    And the output should not contain "Hello"

  # @author zzhao@redhat.com
  # @case_id OCP-22735
  @admin
  @upgrade-check
  Scenario: Check the networkpolicy works well after upgrade
    Given I switch to cluster admin pseudo user		
    When I use the "policy-upgrade" project
    Given status becomes :running of 2 pods labeled:
      | name=test-pods |
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
