Feature: testing for parameter fsType

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  @admin
  Scenario Outline: persistent volume formated with fsType
    Given I have a project
    And I have a 1 GB volume and save volume id in the :vid clipboard
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/<type>/security/<type>-selinux-fsgroup-test.json" replacing paths:
      | ["metadata"]["name"]                                      | pod-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"] | /mnt                    |
      | ["spec"]["securityContext"]["fsGroup"]                    | 24680                   |
      | ["spec"]["volumes"][0]["<storage_type>"]["<volume_name>"] | <%= cb.vid %>           |
      | ["spec"]["volumes"][0]["<storage_type>"]["fsType"]        | <fsType>                |
    Then the step should succeed
    And the pod named "pod-<%= project.name %>" becomes ready
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
      | fsType | storage_type         | volume_name | type   |
      | ext3   | gcePersistentDisk    | pdName      | gce    | # @case_id OCP-10095
      | ext4   | gcePersistentDisk    | pdName      | gce    | # @case_id OCP-10094
      | xfs    | gcePersistentDisk    | pdName      | gce    | # @case_id OCP-10096
      | ext3   | awsElasticBlockStore | volumeID    | ebs    | # @case_id OCP-10048
      | ext4   | awsElasticBlockStore | volumeID    | ebs    | # @case_id OCP-9612
      | xfs    | awsElasticBlockStore | volumeID    | ebs    | # @case_id OCP-10049
      | ext3   | cinder               | volumeID    | cinder | # @case_id OCP-10097
      | ext4   | cinder               | volumeID    | cinder | # @case_id OCP-10098
      | xfs    | cinder               | volumeID    | cinder | # @case_id OCP-10099

