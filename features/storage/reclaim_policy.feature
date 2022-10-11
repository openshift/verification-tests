Feature: Persistent Volume reclaim policy tests

  # @author lxia@redhat.com
  @admin
  @singlenode
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Persistent volume with RWO access mode and Delete policy
    Given I have a project
    And I have a 1 GB volume and save volume id in the :vid clipboard

    Given I obtain test data file "storage/<path>/<file>"
    When admin creates a PV from "<file>" where:
      | ["metadata"]["name"]                        | pv-<%= project.name %> |
      | ["spec"]["capacity"]["storage"]             | 1Gi                    |
      | ["spec"]["accessModes"][0]                  | ReadWriteOnce          |
      | ["spec"]["<storage_type>"]["<volume_name>"] | <%= cb.vid %>          |
      | ["spec"]["persistentVolumeReclaimPolicy"]   | Delete                 |
      | ["spec"]["storageClassName"]                | sc-<%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV

    Given I obtain test data file "storage/gce/pod.json"
    When I run oc create over "pod.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    When I execute on the pod:
      | touch | /mnt/testfile |
    Then the step should succeed

    Given I ensure "mypod" pod is deleted
    And I ensure "mypvc" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pv.name %>" to disappear within 1200 seconds

    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id          | storage_type      | volume_name | path | file                |
      | OCP-9949:Storage | gcePersistentDisk | pdName      | gce  | pv-default-rwo.json | # @case_id OCP-9949

    @aws-ipi
    @aws-upi
    Examples:
      | case_id          | storage_type         | volume_name | path | file        |
      | OCP-9943:Storage | awsElasticBlockStore | volumeID    | ebs  | pv-rwo.yaml | # @case_id OCP-9943

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id          | storage_type | volume_name | path   | file                |
      | OCP-9944:Storage | cinder       | volumeID    | cinder | pv-rwx-default.json | # @case_id OCP-9944
