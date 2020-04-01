Feature: NFS Persistent Volume

  # @author jhou@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-9572
  @admin
  Scenario: Share NFS with multiple pods with ReadWriteMany mode
    Given I have a project
    And I have a NFS service in the project

    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pv-retain.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %>           |
      | ["spec"]["nfs"]["server"]    | <%= service("nfs-service").ip %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>           |
    And I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/auto/pvc-rwx.json" replacing paths:
      | ["spec"]["volumeName"]       | <%= pv.name %>         |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the PV becomes :bound

    # Create a replication controller
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/nfs/auto/rc.yml |
    Then the step should succeed

    # The replication controller creates 2 pods
    Given 2 pods become ready with labels:
      | name=hellopod |

    When I execute on the "<%= pod(-1).name %>" pod:
      | touch | /mnt/nfs/testfile_1 |
    Then the step should succeed

    When I execute on the "<%= pod(-2).name %>" pod:
      | touch | /mnt/nfs/testfile_2 |
    Then the step should succeed

    # Delete the rc to ensure the data synced to the nfs server
    Given I ensure "hellopod" replicationcontroller is deleted

    # Finally verify both files created by each pod are under the same export dir in the nfs-server pod
    When I execute on the "nfs-server" pod:
      | ls | /mnt/data |
    Then the output should contain:
      | testfile_1 |
      | testfile_2 |

  # @author chaoyang@redhat.com
  @admin
  @destructive
  Scenario Outline: Check GIDs specified in a PV's annotations to pod's supplemental groups
    Given I have a project
    And I have a NFS service in the project
    When I execute on the pod:
      | chown | <nfs-uid-gid> | /mnt/data |
    Then the step should succeed
    When I execute on the pod:
      | chmod | -R | 770 | /mnt/data |
    Then the step should succeed

    When admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/pv-gid.json" where:
      | ["spec"]["nfs"]["server"]                                | <%= service("nfs-service").ip %> |
      | ["spec"]["nfs"]["path"]                                  | /                                |
      | ["spec"]["capacity"]["storage"]                          | 1Gi                              |
      | ["metadata"]["name"]                                     | nfs-<%= project.name %>          |
      | ["metadata"]["annotations"]["pv.beta.kubernetes.io/gid"] | "<pv-gid>"                       |
    Then the step should succeed

    When I create a manual pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwx.json" replacing paths:
      | ["metadata"]["name"]                         | nfsc |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi  |
    Then the step should succeed
    And the "nfsc" PVC becomes bound to the "nfs-<%= project.name %>" PV

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/nfs/security/pod-supplementalgroup.json" replacing paths:
      | ["metadata"]["name"]                                         | nfspd |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | nfsc  |
    Then the step should succeed
    And the pod named "nfspd" becomes ready

    When I execute on the pod:
      | id | -u |
    Then the output should contain:
      | 101 |
    When I execute on the pod:
      | id | -G |
    Then the output should contain 1 times:
      | <pod-gid> |
    Given I execute on the pod:
      | touch | /mnt/nfs/nfs_testfile |
    Then the step should succeed
    # workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1810971
    Then I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /mnt/nfs/nfs_testfile |
    Then the step should succeed
    """

    Examples:
      | nfs-uid-gid   | pv-gid | pod-gid |
      | 1234:1234     | 1234   | 1234    | # @case_id OCP-10930
      | 111111:111111 | 111111 | 111111  | # @case_id OCP-10282

  # @author chaoyang@redhat.com
  # @case_id OCP-10281
  @admin
  Scenario: Permission denied when nfs pv annotaion is not right
    Given I have a project
    And I have a NFS service in the project
    When I execute on the pod:
      | chown | 1234:1234 | /mnt/data |
    Then the step should succeed
    When I execute on the pod:
      | chmod | -R | 770 | /mnt/data |
    Then the step should succeed

    Given admin creates a PV from "<%= BushSlicer::HOME %>/testdata/storage/nfs/pv-gid.json" where:
      | ["spec"]["nfs"]["server"]                                | <%= service("nfs-service").ip %> |
      | ["spec"]["nfs"]["path"]                                  | /                                |
      | ["spec"]["capacity"]["storage"]                          | 1Gi                              |
      | ["metadata"]["name"]                                     | nfs-<%= project.name %>          |
      | ["metadata"]["annotations"]["pv.beta.kubernetes.io/gid"] | abc123                           |
    Then the step should succeed

    When I create a manual pvc from "<%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwx.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                      |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "nfs-<%= project.name %>" PV

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/nfs/security/pod-supplementalgroup.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc  |
    Then the step should succeed
    And the pod named "mypod" becomes ready

    Given I execute on the "mypod" pod:
      | touch | /mnt/nfs/nfs_testfile |
    Then the step should fail
    And the output should contain:
      | Permission denied |

