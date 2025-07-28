Feature: kubelet restart and node restart

  # @author wduan@redhat.com
  @admin
  @destructive
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: kubelet restart should not affect attached/mounted volumes
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    Given I obtain test data file "storage/misc/deployment.yaml"
    When I run oc create over "deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep        |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | storage      |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc        |
      | ["spec"]["template"]["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/storage |
    Then the step should succeed
    And the "mypvc" PVC becomes :bound
    And a pod becomes ready with labels:
      | action=storage |

    When I execute on the pod:
      | touch | /mnt/storage/testfile_before_restart |
    Then the step should succeed
    # restart kubelet on the node
    Given I use the "<%= pod.node_name %>" node
    And the node service is restarted on the host
    # wait some time in case pod becomes to Terminating
    And 30 seconds have passed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | /mnt/storage/testfile_before_restart |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/storage/testfile_after_restart |
    Then the step should succeed
    """

    @rosa @osd_ccs @aro
    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | platform   |
      | OCP-13333:Storage | azure-disk | # @case_id OCP-13333

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id           | platform |
      | OCP-11317:Storage | cinder   | # @case_id OCP-11317

    @rosa @osd_ccs @aro
    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | platform |
      | OCP-11613:Storage | gce      | # @case_id OCP-11613

    @vsphere-ipi
    @vsphere-upi
    @hypershift-hosted
    @critical
    @inactive
    Examples:
      | case_id           | platform       |
      | OCP-13631:Storage | vsphere-volume | # @case_id OCP-13631
