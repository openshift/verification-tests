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

  @upgrade-prepare
  @admin
  Scenario: upgrade with running router pods on all worker nodes - prepare
    # Get the number of worker nodes and scale up router pods
    Given I switch to cluster admin pseudo user
    And I store the number of worker nodes to the :num_workers clipboard
    When I run the :scale admin command with:
      | resource | ingresscontroller          |
      | name     | default                    |
      | replicas | <%= cb.num_workers %>      |
      | n        | openshift-ingress-operator |
    Then the step should succeed
    Given I use the "openshift-ingress" project
    And I wait up to 180 seconds for the steps to pass:
    """
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_workers %>
    And <%= cb.num_workers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |
    """

  # @author hongli@redhat.com
  # @case_id OCP-30501
  @upgrade-check
  @admin
  Scenario: upgrade with running router pods on all worker nodes
    Given I switch to cluster admin pseudo user
    And I store the number of worker nodes to the :num_workers clipboard
    Given I use the "openshift-ingress" project
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_workers %>
    And <%= cb.num_workers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |
