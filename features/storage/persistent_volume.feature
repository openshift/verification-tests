Feature: Persistent Volume Claim binding policies

  # @author jhou@redhat.com
  # @author chaoyang@redhat.com
  @admin
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PVC with one accessMode can bind PV with all accessMode
    Given I have a project

    # Create 2 PVs
    # Create PV with all accessMode
    Given I obtain test data file "storage/nfs/auto/pv-template-all-access-modes.json"
    When admin creates a PV from "pv-template-all-access-modes.json" where:
      | ["metadata"]["name"]         | pv1-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed
    # Create PV without accessMode3
    Given I obtain test data file "storage/nfs/auto/pv.json"
    When admin creates a PV from "pv.json" where:
      | ["metadata"]["name"]         | pv2-<%= project.name %> |
      | ["spec"]["accessModes"][0]   | <accessMode1>           |
      | ["spec"]["accessModes"][1]   | <accessMode2>           |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
    Then the step should succeed

    # Create PVC with accessMode3
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["accessModes"][0]   | <accessMode3>          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed

    And the "mypvc" PVC becomes bound to the "pv1-<%= project.name %>" PV
    And the "pv2-<%= project.name %>" PV status is :available

    @rosa @osd_ccs @aro
    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @hypershift-hosted
    Examples:
      | case_id           | accessMode1   | accessMode2   | accessMode3   |
      | OCP-9702:Storage  | ReadOnlyMany  | ReadWriteMany | ReadWriteOnce | # @case_id OCP-9702
      | OCP-10680:Storage | ReadWriteOnce | ReadOnlyMany  | ReadWriteMany | # @case_id OCP-10680
      | OCP-11168:Storage | ReadWriteMany | ReadWriteOnce | ReadOnlyMany  | # @case_id OCP-11168

  # @author yinzhou@redhat.com
  # @case_id OCP-11933
  @inactive
  @storage
  Scenario: OCP-11933:Workloads deployment hook volume inheritance -- with persistentvolumeclaim Volume
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | nfsc |
    Then the step should succeed
    And I wait for the "nfsc" pvc to appear

    Given I obtain test data file "cases/510610/hooks-with-nfsvolume.json"
    When I run the :create client command with:
      | f | hooks-with-nfsvolume.json |
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

  # @author wduan@redhat.com
  @admin
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PV can not bind PVC which request more storage
    Given I have a project
    # PV is 100Mi and PVC is 1Gi
    Given I obtain test data file "storage/nfs/auto/pv-template.json"
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"]            | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0]      | <access_mode>          |
      | ["spec"]["capacity"]["storage"] | 100Mi                  |
      | ["spec"]["storageClassName"]    | sc-<%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["accessModes"][0]   | <access_mode>          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    And the "mypvc" PVC becomes :pending

    @rosa @osd_ccs @aro
    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @hypershift-hosted
    Examples:
      | case_id           | access_mode   |
      | OCP-26880:Storage | ReadOnlyMany  | # @case_id OCP-26880
      | OCP-26881:Storage | ReadWriteMany | # @case_id OCP-26881
      | OCP-26879:Storage | ReadWriteOnce | # @case_id OCP-26879


  # @author wduan@redhat.com
  @admin
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PV can not bind PVC with mismatched accessMode
    Given I have a project
    Given I obtain test data file "storage/nfs/auto/pv-template.json"
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0]   | <pv_access_mode>       |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc1                 |
      | ["spec"]["accessModes"][0]   | <pvc_access_mode1>     |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc2                 |
      | ["spec"]["accessModes"][0]   | <pvc_access_mode2>     |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV status is :available
    And the "mypvc1" PVC becomes :pending
    And the "mypvc2" PVC becomes :pending

    @rosa @osd_ccs @aro
    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @hypershift-hosted
    Examples:
      | case_id           | pv_access_mode | pvc_access_mode1 | pvc_access_mode2 |
      | OCP-26882:Storage | ReadOnlyMany   | ReadWriteMany    | ReadWriteOnce    | # @case_id OCP-26882
      | OCP-26883:Storage | ReadWriteMany  | ReadWriteOnce    | ReadOnlyMany     | # @case_id OCP-26883
      | OCP-26884:Storage | ReadWriteOnce  | ReadOnlyMany     | ReadWriteMany    | # @case_id OCP-26884
