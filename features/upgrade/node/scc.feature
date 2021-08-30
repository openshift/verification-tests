Feature: Seccomp part of SCC policy should be kept and working after upgrade

  # @author sunilc@redhat.com
  @upgrade-prepare
  @admin
  Scenario: Seccomp part of SCC policy should be kept and working after upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given I obtain test data file "node/scc.yaml"
    When I run the :create client command with:
      | f | scc.yaml |
    Then the step should succeed

  # @author sunilc@redhat.com
  # @case_id OCP-13065
  @upgrade-check
  @admin
  @aws-ipi
  Scenario: Seccomp part of SCC policy should be kept and working after upgrade
    Given I switch to cluster admin pseudo user
    Given admin checks that the "seccomp" scc exists
