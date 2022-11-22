Feature: testing for parameter fsType

  # @author chaoyang@redhat.com
  @admin
  @smoke
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: persistent volume formated with fsType
    Given I have a project
    And admin creates new in-tree storageclass with:
      | ["metadata"]["name"]     | sc-<%= project.name %> |
      | ["parameters"]["fsType"] | <fsType>               |
    Given I obtain test data file "storage/misc/pvc-with-storageClassName.json"
    When I run oc create over "pvc-with-storageClassName.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt  |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    When I execute on the pod:
      | mount |
    Then the step should succeed
    And the output should contain:
      | /mnt type <fsType> |
    When I execute on the pod:
      | touch | /mnt/testfile |
    Then the step should succeed
    When I execute on the pod:
      | ls | /mnt/testfile |
    Then the step should succeed

    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | fsType | type |
      | OCP-10095:Storage | ext3   | gce  | # @case_id OCP-10095
      | OCP-10094:Storage | ext4   | gce  | # @case_id OCP-10094
      | OCP-10096:Storage | xfs    | gce  | # @case_id OCP-10096

    @aws-ipi
    @aws-upi
    Examples:
      | case_id           | fsType | type |
      | OCP-10048:Storage | ext3   | ebs  | # @case_id OCP-10048
      | OCP-9612:Storage  | ext4   | ebs  | # @case_id OCP-9612
      | OCP-10049:Storage | xfs    | ebs  | # @case_id OCP-10049

    @openstack-ipi
    @openstack-upi
    @hypershift-hosted
    Examples:
      | case_id           | fsType | type   |
      | OCP-10097:Storage | ext3   | cinder | # @case_id OCP-10097
      | OCP-10098:Storage | ext4   | cinder | # @case_id OCP-10098
      | OCP-10099:Storage | xfs    | cinder | # @case_id OCP-10099
