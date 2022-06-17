Feature: Testing for pv and pvc pre-bind feature

  # @author chaoyang@redhat.com
  # @case_id OCP-10107
  @admin
  @destructive
  Scenario: OCP-10107 Prebound pv is availabe due to requested pvc status is bound
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv1-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                        |
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                      |
    And the "nfsc-<%= project.name %>" PVC becomes bound to the "nfspv1-<%= project.name %>" PV
    Then admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | nfspv2-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>        |
      | ["spec"]["claimRef"]["name"]      | nfsc-<%= project.name %>   |
    And the "nfspv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-10109
  @admin
  Scenario: OCP-10109 Prebound pv is availabe due to mismatched accessmode with requested pvc
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | nfspv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>       |
      | ["spec"]["claimRef"]["name"]      | nfsc-<%= project.name %>  |
    Then the step should succeed
    And the "nfspv-<%= project.name %>" PV status is :available
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | nfsc-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteMany            |
    And the "nfsc-<%= project.name %>" PVC becomes :pending
    And the "nfspv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-10111
  @admin
  @destructive
  Scenario: OCP-10111 Prebound pvc is pending due to requested pv status is bound
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv1-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                        |
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                      |
    And the "nfsc-<%= project.name %>" PVC becomes bound to the "nfspv1-<%= project.name %>" PV
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]   | nfsc-prebound-<%= project.name %> |
      | ["spec"]["volumeName"] | nfspv1-<%= project.name %>        |
    And the "nfsc-prebound-<%= project.name %>" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @case_id OCP-10113
  @admin
  @destructive
  Scenario: OCP-10113 Prebound PVC is pending due to mismatched accessmode with requested PV
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                       |
    Then the step should succeed
    And the "nfspv-<%= project.name %>" PV status is :available
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]       | nfsc-<%= project.name %>   |
      | ["spec"]["volumeName"]     | nfspv-<%= project.name %>  |
      | ["spec"]["accessModes"][0] | ReadWriteMany              |
    And the "nfsc-<%= project.name %>" PVC becomes :pending
    And the "nfspv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-10114
  @admin
  @destructive
  Scenario: OCP-10114 Prebound PVC is pending due to mismatched volume size with requested PV
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                       |
    Then the step should succeed
    And the "nfspv-<%= project.name %>" PV status is :available
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]                         | nfsc-<%= project.name %>   |
      | ["spec"]["volumeName"]                       | nfspv-<%= project.name %>  |
      | ["spec"]["resources"]["requests"]["storage"] | 2Gi                        |
    And the "nfsc-<%= project.name %>" PVC becomes :pending
    And the "nfspv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-9941
  @admin
  @destructive
  Scenario: OCP-9941 PV and PVC bound successfully when pvc created prebound to pv
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv1-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                        |
      | ["spec"]["accessModes"][0]      | ReadWriteMany              |
      | ["spec"]["accessModes"][1]      | ReadWriteOnce              |
      | ["spec"]["accessModes"][2]      | ReadOnlyMany               |
    Then the step should succeed
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]            | nfspv2-<%= project.name %> |
      | ["spec"]["capacity"]["storage"] | 1Gi                        |
    Then the step should succeed
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %>   |
      | ["spec"]["volumeName"] | nfspv1-<%= project.name %> |
    And the "nfsc-<%= project.name %>" PVC becomes bound to the "nfspv1-<%= project.name %>" PV
    And the "nfspv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-9940
  @admin
  @destructive
  Scenario: OCP-9940 PV and PVC bound successfully when pv created prebound to pvc
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | nfspv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>       |
      | ["spec"]["claimRef"]["name"]      | nfsc2-<%= project.name %> |
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc1-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                       |
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc2-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                       |
    And the "nfsc2-<%= project.name %>" PVC becomes bound to the "nfspv-<%= project.name %>" PV
    And the "nfsc1-<%= project.name %>" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @case_id OCP-9939
  @admin
  @destructive
  Scenario: OCP-9939 PVC is bond to PV successfully when pvc is created first
    Given I have a project
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc-<%= project.name %> |
    Then admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs-recycle-rwo.json" where:
      | ["metadata"]["name"]              | nfspv-<%= project.name %> |
    And the "nfsc-<%= project.name %>" PVC becomes bound to the "nfspv-<%= project.name %>" PV within 60 seconds

  # @author chaoyang@redhat.com
  @admin
  @destructive
  Scenario Outline: Prebound pv/pvc is availabe/pending due to requested pvc/pv prebound to other pv/pvc
    Given I have a project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | nfspv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>       |
      | ["spec"]["claimRef"]["name"]      | <pre-bind-pvc>            |
    Then the step should succeed
    And the "nfspv-<%= project.name %>" PV status is :available
    Then I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %> |
      | ["spec"]["volumeName"] | <pre-bind-pv>            |
    And the "nfsc-<%= project.name %>" PVC becomes :pending
    And the "nfspv-<%= project.name %>" PV status is :available
    Examples:
      | pre-bind-pvc | pre-bind-pv                |
      | nfsc         | nfspv1-<%= project.name %> | # @case_id OCP-10108
      | nfsc1        | nfspv-<%= project.name %>  | # @case_id OCP-10112

