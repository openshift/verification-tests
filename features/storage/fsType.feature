Feature: testing for parameter fsType

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  @admin
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @aws-upi
  Scenario Outline: persistent volume formated with fsType
    Given I have a project
    And admin clones storage class "sc-<%= project.name %>" from ":default" with:
      | ["parameters"]["fsType"] | <fsType> |
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

    Examples:
      | fsType | type   |
      | ext3   | gce    | # @case_id OCP-10095
      | ext4   | gce    | # @case_id OCP-10094
      | xfs    | gce    | # @case_id OCP-10096
      | ext3   | ebs    | # @case_id OCP-10048
      | ext4   | ebs    | # @case_id OCP-9612
      | xfs    | ebs    | # @case_id OCP-10049
      | ext3   | cinder | # @case_id OCP-10097
      | ext4   | cinder | # @case_id OCP-10098
      | xfs    | cinder | # @case_id OCP-10099

