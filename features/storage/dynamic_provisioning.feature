Feature: Dynamic provisioning

  # @author wduan@redhat.com
  @admin
  @smoke
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: dynamic provisioning
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    Given I obtain test data file "storage/misc/deployment.yaml"
    When I run oc create over "deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep                 |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | storage               |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc                 |
      | ["spec"]["template"]["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/<cloud_provider> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    And the "mypvc" PVC becomes :bound
    And I save volume id from PV named "<%= pvc.volume_name %>" in the :volumeID clipboard
    When I execute on the pod:
      | touch | /mnt/<cloud_provider>/testfile_1 |
    Then the step should succeed

    When I run the :scale client command with:
      | resource | deployment |
      | name     | mydep      |
      | replicas | 0          |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    When I run the :scale client command with:
      | resource | deployment |
      | name     | mydep      |
      | replicas | 1          |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    When I execute on the pod:
      | ls | -l | /mnt/<cloud_provider>/testfile_1 |
    Then the step should succeed

    Given I ensure "mydep" deployment is deleted
    And I ensure "<%= pvc.name %>" pvc is deleted

    Given I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 1200 seconds

    Given I use the "<%= pod.node_name %>" node
    When I run commands on the host:
      | mount |
    Then the step should succeed
    And the output should not contain:
      | <%= pvc.volume_name %> |
      | <%= cb.volumeID %>     |
    # And I verify that the IAAS volume with id "<%= cb.volumeID %>" was deleted

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    Examples:
      | case_id          | cloud_provider |
      | OCP-9685:Storage | ebs            | # @case_id OCP-9685

    @rosa @osd_ccs @aro
    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | cloud_provider |
      | OCP-12665:Storage | gce            | # @case_id OCP-12665

    @rosa @osd_ccs @aro
    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | cloud_provider |
      | OCP-13787:Storage | azure          | # @case_id OCP-13787

    @openstack-ipi
    @openstack-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id          | cloud_provider |
      | OCP-9656:Storage | cinder         | # @case_id OCP-9656
