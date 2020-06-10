Feature: Seccomp part of SCC policy should be kept and working after upgrade	

  # @author sunilc@redhat.com
  @upgrade-prepare
  @admin
  Scenario: Upgrade - Seccomp part of SCC policy should be kept and working after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | node-upgrade-scc |
    And I use the "node-upgrade-scc" project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/features/tierN/testdata/node/scc.yaml |
    Then the step should succeed

  # @author sunilc@redhat.com
  # @case_id OCP-13065
  @upgrade-check
  @admin
  Scenario: Upgrade - Make sure seccomp part of SCC policy is kept after upgrade 
    Given I switch to cluster admin pseudo user
    When I use the "node-upgrade-scc" project
    Given admin checks that the "seccomp" scc exists    
    #When I run the :get admin command with:
    #  | resource      | scc     |
    #  | resource name | seccomp |
    #Then the step should succeed
    #And the output should contain:
    #  | seccomp |
