Feature: Testing for pv and pvc pre-bind feature

  # @author chaoyang@redhat.com
  # @case_id OCP-10107
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10107 Prebound pv is availabe due to requested pvc status is bound
    Given I have a project
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Given I obtain test data file "storage/nfs/claim-rwo.json"
    Then I create a dynamic pvc from "claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes bound to the "pv1-<%= project.name %>" PV
    Given I obtain test data file "storage/nfs/preboundpv-rwo.yaml"
    Then admin creates a PV from "preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv2-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>     |
      | ["spec"]["claimRef"]["name"]      | mypvc                   |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %>  |
    And the "pv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10109
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10109 Prebound pv is availabe due to mismatched accessmode with requested pvc
    Given I have a project
    Given I obtain test data file "storage/nfs/preboundpv-rwo.yaml"
    Given admin creates a PV from "preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | mypvc                  |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Given I obtain test data file "storage/nfs/claim-rwo.json"
    Then I create a dynamic pvc from "claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["accessModes"][0]   | ReadWriteMany          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10111
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10111 Prebound pvc is pending due to requested pv status is bound
    Given I have a project
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Given I obtain test data file "storage/nfs/claim-rwo.json"
    Then I create a dynamic pvc from "claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV
    Given I obtain test data file "storage/nfs/preboundpvc-rwo.yaml"
    Then I create a dynamic pvc from "preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | nfsc-prebound          |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "nfsc-prebound" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10113
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10113 Prebound PVC is pending due to mismatched accessmode with requested PV
    Given I have a project
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Given I obtain test data file "storage/nfs/preboundpvc-rwo.yaml"
    Then I create a dynamic pvc from "preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0]   | ReadWriteMany          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10114
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10114 Prebound PVC is pending due to mismatched volume size with requested PV
    Given I have a project
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Given I obtain test data file "storage/nfs/preboundpvc-rwo.yaml"
    Then I create a dynamic pvc from "preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]                         | mypvc                  |
      | ["spec"]["volumeName"]                       | pv-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 8Gi                    |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-9941
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-9941 PV and PVC bound successfully when pvc created prebound to pv
    Given I have a project
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed
    Given I obtain test data file "storage/nfs/nfs.json"
    Given admin creates a PV from "nfs.json" where:
      | ["metadata"]["name"]         | pv2-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed
    Given I obtain test data file "storage/nfs/preboundpvc-rwo.yaml"
    Then I create a dynamic pvc from "preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                   |
      | ["spec"]["volumeName"]       | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    And the "mypvc" PVC becomes bound to the "pv1-<%= project.name %>" PV
    And the "pv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-9940
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-9940 PV and PVC bound successfully when pv created prebound to pvc
    Given I have a project
    Given I obtain test data file "storage/nfs/preboundpv-rwo.yaml"
    Given admin creates a PV from "preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | mypvc2                 |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Given I obtain test data file "storage/nfs/claim-rwo.json"
    Then I create a dynamic pvc from "claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc1                 |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Given I obtain test data file "storage/nfs/claim-rwo.json"
    Then I create a dynamic pvc from "claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc2                 |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc2" PVC becomes bound to the "pv-<%= project.name %>" PV
    And the "mypvc1" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Prebound pv/pvc is availabe/pending due to requested pvc/pv prebound to other pv/pvc
    Given I have a project
    Given I obtain test data file "storage/nfs/preboundpv-rwo.yaml"
    Given admin creates a PV from "preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | <pre-bind-pvc>         |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Given I obtain test data file "storage/nfs/preboundpvc-rwo.yaml"
    Then I create a dynamic pvc from "preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | <pre-bind-pv>          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available
    @singlenode
    @proxy @noproxy @disconnected @connected
    @heterogeneous @arm64 @amd64
    Examples:
      | case_id   | pre-bind-pvc | pre-bind-pv                |
      | OCP-10108 | nfsc         | nfspv1-<%= project.name %> | # @case_id OCP-10108
      | OCP-10112 | nfsc1        | nfspv-<%= project.name %>  | # @case_id OCP-10112

