Feature: Routing and DNS related scenarios
    
  @upgrade-prepare
  @admin
  Scenario: ensure ingress works well before and after upgrade - prepare
    # Check console route
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    Given I run the steps 6 times:
    """
    When I open secure web server via the "console" route
    Then the step should succeed
    """
    
  # @author hongli@redhat.com
  # @case_id OCP-29746
  @upgrade-check
  @admin
  Scenario: ensure ingress works well before and after upgrade
    # Check console route after upgraded
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    Given I run the steps 6 times:
    """
    When I open secure web server via the "console" route
    Then the step should succeed
    """

  @upgrade-prepare
  @admin
  Scenario: ensure DNS works well before and after upgrade - prepare
    # Check service name can be resolvede
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    And I use the "console" service
    And evaluation of `service.ip` is stored in the :console_svc_ip clipboard
    Given I use the "openshift-ingress-operator" project
    And a pod becomes ready with labels:
      | name=ingress-operator |
    Given I execute on the pod:
      | nslookup | console.openshift-console.svc |
    Then the output should contain "<%= cb.console_svc_ip %>"

  # @author hongli@redhat.com
  # @case_id OCP-29747
  @upgrade-check
  @admin
  Scenario: ensure DNS works well before and after upgrade
    # Check service name can be resolvede
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    And I use the "console" service
    And evaluation of `service.ip` is stored in the :console_svc_ip clipboard
    Given I use the "openshift-ingress-operator" project
    And a pod becomes ready with labels:
      | name=ingress-operator |
    Given I execute on the pod:
      | nslookup | console.openshift-console.svc |
    Then the output should contain "<%= cb.console_svc_ip %>"
