Feature: Volume snapshot test

  # @author wduan@redhat.com
  @admin
  @upgrade-sanity
  @qeci
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @storage
  Scenario Outline: Volume snapshot create and restore test
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc-ori |
      | ["spec"]["storageClassName"] | <csi-sc>  |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori  |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-ori" becomes ready
    When I execute on the pod:
      | sh | -c | echo "snapshot test" > /mnt/local/testfile |
    Then the step should succeed
    And I execute on the pod:
      | sh | -c | sync -f /mnt/local/testfile |
    Then the step should succeed
    Given I ensure "mypod-ori" pod is deleted

    #Given admin creates a VolumeSnapshotClass replacing paths:
    #  | ["metadata"]["name"] | snapclass-<%= project.name %> |
    Given I obtain test data file "storage/csi/volumesnapshot_v1.yaml"
    When I run oc create over "volumesnapshot_v1.yaml" replacing paths:
      | ["metadata"]["name"]                            | mysnapshot |
      | ["spec"]["volumeSnapshotClassName"]             | <csi-vsc>  |
      | ["spec"]["source"]["persistentVolumeClaimName"] | mypvc-ori  |
    Then the step should succeed
    And the "mysnapshot" volumesnapshot becomes ready
    Given I obtain test data file "storage/csi/pvc-snapshot.yaml"
    When I create a dynamic pvc from "pvc-snapshot.yaml" replacing paths:
      | ["metadata"]["name"]           | mypvc-snap |
      | ["spec"]["storageClassName"]   | <csi-sc>   |
      | ["spec"]["dataSource"]["name"] | mysnapshot |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-snap |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-snap |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-snap" becomes ready
    And the "mypvc-snap" PVC becomes :bound
    When I execute on the "mypod-snap" pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "snapshot test"

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    Examples:
      | case_id           | csi-sc  | csi-vsc     |
      | OCP-27727:Storage | gp2-csi | csi-aws-vsc | # @case_id OCP-27727

    @rosa @osd_ccs @aro
    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | csi-sc      | csi-vsc           |
      | OCP-41449:Storage | managed-csi | csi-azuredisk-vsc | # @case_id OCP-41449

    @openstack-ipi
    @openstack-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id           | csi-sc       | csi-vsc      |
      | OCP-37568:Storage | standard-csi | standard-csi | # @case_id OCP-37568

  # @author wduan@redhat.com
  @admin
  @upgrade-sanity
  @qeci
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @storage
  Scenario Outline: Volume snapshot create and restore test with block
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc-ori |
      | ["spec"]["storageClassName"] | <csi-sc>  |
      | ["spec"]["volumeMode"]       | Block     |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod-with-block-volume.yaml"
    When I run oc create over "pod-with-block-volume.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori   |
      | ["spec"]["containers"][0]["volumeDevices"][0]["devicePath"]  | /dev/dblock |
    Then the step should succeed
    And the pod named "mypod-ori" becomes ready
    # Using the dd and echo cmd to write readable data into raw block device
    # In restore step, dd cmd can copy the data from raw block device to a file to verify
    When I execute on the pod:
      | /bin/dd | if=/dev/zero | of=/dev/dblock | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | echo "test data" > /dev/dblock |
    Then the step should succeed
    When I execute on the pod:
      | sync |
    Then the step should succeed
    Given I ensure "mypod-ori" pod is deleted

    #Given admin creates a VolumeSnapshotClass replacing paths:
    #  | ["metadata"]["name"] | snapclass-<%= project.name %> |
    Given I obtain test data file "storage/csi/volumesnapshot_v1.yaml"
    When I run oc create over "volumesnapshot_v1.yaml" replacing paths:
      | ["metadata"]["name"]                            | mysnapshot |
      | ["spec"]["volumeSnapshotClassName"]             | <csi-vsc>  |
      | ["spec"]["source"]["persistentVolumeClaimName"] | mypvc-ori  |
    Then the step should succeed
    And the "mysnapshot" volumesnapshot becomes ready
    Given I obtain test data file "storage/csi/pvc-snapshot.yaml"
    When I create a dynamic pvc from "pvc-snapshot.yaml" replacing paths:
      | ["metadata"]["name"]           | mypvc-snap |
      | ["spec"]["storageClassName"]   | <csi-sc>   |
      | ["spec"]["dataSource"]["name"] | mysnapshot |
      | ["spec"]["volumeMode"]         | Block      |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod-with-block-volume.yaml"
    When I run oc create over "pod-with-block-volume.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-snap  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-snap  |
      | ["spec"]["containers"][0]["volumeDevices"][0]["devicePath"]  | /dev/dblock |
    Then the step should succeed
    Given the pod named "mypod-snap" becomes ready
    When I execute on the pod:
      | /bin/dd | if=/dev/dblock | of=/tmp/testfile | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | cat /tmp/testfile |
    Then the step should succeed
    And the output should contain "test data"

    @openstack-ipi
    @openstack-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id           | csi-sc       | csi-vsc      |
      | OCP-37569:Storage | standard-csi | standard-csi | # @case_id OCP-37569
