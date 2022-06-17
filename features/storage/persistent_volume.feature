Feature: Persistent Volume Claim binding policies

  # @author jhou@redhat.com
  # @author wehe@redhat.com
  # @author chaoyang@redhat.com
  @admin
  @destructive
  Scenario Outline: PVC with one accessMode can bind PV with all accessMode
    # Preparations
    Given I have a project

    # Create 2 PVs
    # Create PV with all accessMode
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template-all-access-modes.json" where:
      | ["metadata"]["name"] | nfs-<%= project.name %> |
    Then the step should succeed
    # Create PV without accessMode3
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv.json" where:
      | ["metadata"]["name"]       | nfs1-<%= project.name %> |
      | ["spec"]["accessModes"][0] | <accessMode1>            |
      | ["spec"]["accessModes"][1] | <accessMode2>            |
    Then the step should succeed

    # Create PVC with accessMode3
    Given I ensure "nfsc" pvc is deleted after scenario
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["spec"]["accessModes"][0] | <accessMode3> |
    Then the step should succeed

    # First PV can bound
    And the "nfsc" PVC becomes bound to the "nfs-<%= project.name %>" PV
    # Second PV can not bound
    And the "nfs1-<%= project.name %>" PV status is :available


    Examples:
      | accessMode1   | accessMode2   | accessMode3   |
      | ReadOnlyMany  | ReadWriteMany | ReadWriteOnce | # @case_id OCP-9702
      | ReadOnlyMany  | ReadWriteOnce | ReadWriteMany | # @case_id OCP-10680
      | ReadWriteMany | ReadWriteOnce | ReadOnlyMany  | # @case_id OCP-11168

  # @author yinzhou@redhat.com
  # @case_id OCP-11933
  Scenario: OCP-11933 deployment hook volume inheritance -- with persistentvolumeclaim Volume
    Given I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | nfsc |
    Then the step should succeed
    And the "nfsc" PVC becomes :bound

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/510610/hooks-with-nfsvolume.json |
    Then the step should succeed
  ## mount should be correct to the pod, no-matter if the pod is completed or not, check the case checkpoint
    And I wait for the steps to pass:
    """
    When I get project pod named "hooks-1-hook-pre" as YAML
    Then the output by order should match:
      | - mountPath: /opt1     |
      | name: v1               |
      | persistentVolumeClaim: |
      | claimName: nfsc        |
    """

  # @author wehe@redhat.com
  # @author chaoyang@redhat.com
  # @case_id OCP-9931
  @admin
  @destructive
  Scenario: OCP-9931 PV can not bind PVC which request more storage and mismatched accessMode
    Given I have a project
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["metadata"]["name"]       | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadOnlyMany           |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | pvc1-<%= project.name %> |
      | ["spec"]["accessModes"][0]                   | ReadOnlyMany             |
      | ["spec"]["resources"]["requests"]["storage"] | 10Gi                     |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc2-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteOnce            |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc3-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteMany            |
    Then the step should succeed
    And the "pvc1-<%= project.name %>" PVC becomes :pending
    And the "pvc2-<%= project.name %>" PVC becomes :pending
    And the "pvc3-<%= project.name %>" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available
    Given I ensure "pvc1-<%= project.name %>" pvc is deleted
    And I ensure "pvc2-<%= project.name %>" pvc is deleted
    And I ensure "pvc3-<%= project.name %>" pvc is deleted
    And admin ensures "pv-<%= project.name %>" pv is deleted

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["metadata"]["name"]       | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteOnce          |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | pvc1-<%= project.name %> |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce            |
      | ["spec"]["resources"]["requests"]["storage"] | 10Gi                     |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc2-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadOnlyMany             |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc3-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteMany            |
    Then the step should succeed
    And the "pvc1-<%= project.name %>" PVC becomes :pending
    And the "pvc2-<%= project.name %>" PVC becomes :pending
    And the "pvc3-<%= project.name %>" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available
    Given I ensure "pvc1-<%= project.name %>" pvc is deleted
    And I ensure "pvc2-<%= project.name %>" pvc is deleted
    And I ensure "pvc3-<%= project.name %>" pvc is deleted
    And admin ensures "pv-<%= project.name %>" pv is deleted

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["metadata"]["name"]       | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteMany          |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]                         | pvc1-<%= project.name %> |
      | ["spec"]["accessModes"][0]                   | ReadWriteMany            |
      | ["spec"]["resources"]["requests"]["storage"] | 10Gi                     |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc2-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadWriteOnce            |
    Then the step should succeed
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo.json" replacing paths:
      | ["metadata"]["name"]       | pvc3-<%= project.name %> |
      | ["spec"]["accessModes"][0] | ReadOnlyMany             |
    Then the step should succeed
    And the "pvc1-<%= project.name %>" PVC becomes :pending
    And the "pvc2-<%= project.name %>" PVC becomes :pending
    And the "pvc3-<%= project.name %>" PVC becomes :pending
    And the "pv-<%= project.name %>" PV status is :available

  # @author chaoyang@redhat.com
  # @case_id OCP-9937
  @admin
  @destructive
  Scenario: OCP-9937 PV and PVC bound and unbound many times
    Given default storage class is deleted
    Given I have a project
    And I have a NFS service in the project

    #Create 20 pv
    Given I run the steps 20 times:
    """
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/tc522215/pv.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
    Then the step should succeed
    """

    Given 20 PVs become :available within 20 seconds with labels:
      | usedFor=tc522215 |

    #Loop 5 times about pv and pvc bound and unbound
    Given I run the steps 5 times:
    """
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/tc522215/pvc-20.json |
    Given 20 PVCs become :bound within 50 seconds with labels:
      | usedFor=tc522215 |
    Then I run the :delete client command with:
      | object_type | pvc |
      | all         | all |
    Given 20 PVs become :available within 500 seconds with labels:
      | usedFor=tc522215 |
    """

