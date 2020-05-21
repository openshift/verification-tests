Feature: Testing for pv and pvc pre-bind feature

  # @author chaoyang@redhat.com
  # @case_id OCP-10107
  @admin
  Scenario: Prebound pv is availabe due to requested pvc status is bound
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes bound to the "pv1-<%= project.name %>" PV
    Then admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv2-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>     |
      | ["spec"]["claimRef"]["name"]      | mypvc                   |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %>  |
    And the "pv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10109
  @admin
  Scenario: Prebound pv is availabe due to mismatched accessmode with requested pvc
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | mypvc                  |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["accessModes"][0]   | ReadWriteMany          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10111
  @admin
  Scenario: Prebound pvc is pending due to requested pv status is bound
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | nfsc-prebound          |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "nfsc-prebound" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-10113
  @admin
  Scenario: Prebound PVC is pending due to mismatched accessmode with requested PV
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
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
  Scenario: Prebound PVC is pending due to mismatched volume size with requested PV
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
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
  Scenario: PV and PVC bound successfully when pvc created prebound to pv
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/nfs.json" where:
      | ["metadata"]["name"]         | pv2-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                   |
      | ["spec"]["volumeName"]       | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    And the "mypvc" PVC becomes bound to the "pv1-<%= project.name %>" PV
    And the "pv2-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-9940
  @admin
  Scenario: PV and PVC bound successfully when pv created prebound to pvc
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | mypvc2                 |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc1                 |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]         | mypvc2                 |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc2" PVC becomes bound to the "pv-<%= project.name %>" PV
    And the "mypvc1" PVC becomes :pending

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  @admin
  Scenario Outline: Prebound pv/pvc is availabe/pending due to requested pvc/pv prebound to other pv/pvc
    Given I have a project
    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpv-rwo.yaml" where:
      | ["metadata"]["name"]              | pv-<%= project.name %> |
      | ["spec"]["claimRef"]["namespace"] | <%= project.name %>    |
      | ["spec"]["claimRef"]["name"]      | <pre-bind-pvc>         |
      | ["spec"]["storageClassName"]      | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    Then I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/preboundpvc-rwo.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | <pre-bind-pv>          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the "mypvc" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available
    Examples:
      | pre-bind-pvc | pre-bind-pv                |
      | nfsc         | nfspv1-<%= project.name %> | # @case_id OCP-10108
      | nfsc1        | nfspv-<%= project.name %>  | # @case_id OCP-10112

