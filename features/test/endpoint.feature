Feature: test endpoint methods

  @admin
  Scenario: Test endpoint support in the framework
    Given I switch to cluster admin pseudo user
    And admin uses the "default" project
    And evaluation of `endpoints('router').subsets` is stored in the :router_subsets clipboard
    And evaluation of `endpoints('registry-console').subsets` is stored in the :reg_console_subsets clipboard
    Then the expression should be true> cb.reg_console_subsets[0].ports[0].name == 'registry-console'
    Then the expression should be true> cb.router_subsets[0].addresses[0].targetRef.kind == "Pod"

