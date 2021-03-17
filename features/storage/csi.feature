Feature: CSI testing related feature

  # @author chaoyang@redhat.com
  # @case_id OCP-30787
  @admin
  Scenario: CSI images checking in stage and prod env
    Given the master version >= "4.4"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"
    When I run the :get admin command with:
      | resource | volumesnapshot |
    Then the output should contain "true"

  # @author chaoyang@redhat.com
  # @case_id OCP-31345
  @admin
  Scenario: CSI images checking in stage env in OCP4.3
    Given the master version == "4.3"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"

  # @author chaoyang@redhat.com
  # @case_id OCP-31346
  @admin
  Scenario: CSI images checking in stage env in OCP4.2
    Given the master version == "4.2"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running

