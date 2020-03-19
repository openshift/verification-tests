Feature: NoDiskConflict

  # @author lxia@redhat.com
  @admin
  Scenario Outline: [storage_201] Only one pod with the same persistent volume can be scheduled when NoDiskConflicts policy is enabled
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I run the :oadm_new_project admin command with:
      | project_name  | <%= cb.proj_name %>                 |
      | node_selector | <%= cb.proj_name %>=NoDiskConflicts |
      | admin         | <%= user.name %>                    |
    Then the step should succeed

    Given I store the ready and schedulable nodes in the :nodes clipboard
    And label "<%= cb.proj_name %>=NoDiskConflicts" is added to the "<%= cb.nodes[0].name %>" node

    Given I switch to cluster admin pseudo user
    And I use the "<%= cb.proj_name %>" project

    Given I have a 1 GB volume and save volume id in the :volumeID clipboard
    When I run oc create over "<%= ENV['BUSHSLICER_HOME'] %>/testdata/storage/<path_to_file>" replacing paths:
      | ["metadata"]["name"]                                      | mypod1 |
      | ["spec"]["volumes"][0]["<storage_type>"]["<volume_name>"] | <%= cb.volumeID %>       |
    Then the step should succeed
    When I run oc create over "<%= ENV['BUSHSLICER_HOME'] %>/testdata/storage/<path_to_file>" replacing paths:
      | ["metadata"]["name"]                                      | mypod2 |
      | ["spec"]["volumes"][0]["<storage_type>"]["<volume_name>"] | <%= cb.volumeID %>       |
    Then the step should succeed

    When I run the :describe client command with:
      | resource | pod                      |
      | name     | mypod2 |
    Then the step should succeed
    And the output should match:
      | Pending                             |
      | FailedScheduling                    |
      | (NoDiskConflict\|no available disk) |
    When I get project events
    Then the step should succeed
    And the output should match:
      | FailedScheduling                    |
      | (NoDiskConflict\|no available disk) |

    Examples:
      | storage_type         | volume_name | path_to_file |
      | gcePersistentDisk    | pdName      | gce/pod-NoDiskConflict-1.json              | # @case_id OCP-9927
      | awsElasticBlockStore | volumeID    | ebs/security/ebs-selinux-fsgroup-test.json | # @case_id OCP-9929

