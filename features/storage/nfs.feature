Feature: NFS Persistent Volume

  # @author jhou@redhat.com
  # @author lxia@redhat.com
  # @case_id OCP-9572
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-9572:Storage Share NFS with multiple pods with ReadWriteMany mode
    Given I have a project
    And I have a NFS service in the project

    Given I obtain test data file "storage/nfs/auto/pv-retain.json"
    Given admin creates a PV from "pv-retain.json" where:
      | ["metadata"]["name"]         | pv-<%= project.name %>                 |
      | ["spec"]["nfs"]["server"]    | "<%= service("nfs-service").ip_url %>" |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>                 |
    Given I obtain test data file "storage/nfs/auto/pvc-rwx.json"
    And I create a dynamic pvc from "pvc-rwx.json" replacing paths:
      | ["spec"]["volumeName"]       | <%= pv.name %>         |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    And the PV becomes :bound

    # Create a replication controller
    Given I obtain test data file "storage/nfs/auto/rc.yml"
    When I run the :create client command with:
      | f | rc.yml |
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
  # @case_id OCP-10281
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @baremetal-ipi @azure-ipi
  @vsphere-upi @openstack-upi @baremetal-upi @azure-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10281:Storage Permission denied when nfs pv annotaion is not right
    Given I have a project
    And I have a NFS service in the project
    When I execute on the pod:
      | chown | 1234:1234 | /mnt/data |
    Then the step should succeed
    When I execute on the pod:
      | chmod | -R | 770 | /mnt/data |
    Then the step should succeed

    Given I obtain test data file "storage/nfs/pv-gid.json"
    Given admin creates a PV from "pv-gid.json" where:
      | ["spec"]["nfs"]["server"]                                | "<%= service("nfs-service").ip_url %>" |
      | ["spec"]["nfs"]["path"]                                  | /                                      |
      | ["spec"]["capacity"]["storage"]                          | 1Gi                                    |
      | ["metadata"]["name"]                                     | nfs-<%= project.name %>                |
      | ["metadata"]["annotations"]["pv.beta.kubernetes.io/gid"] | abc123                                 |
    Then the step should succeed

    Given I obtain test data file "storage/nfs/claim-rwx.json"
    When I create a manual pvc from "claim-rwx.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi   |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "nfs-<%= project.name %>" PV

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/nfs/security/pod-supplementalgroup.json"
    When I run oc create over "pod-supplementalgroup.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed
    And the pod named "mypod" becomes ready

    Given I execute on the "mypod" pod:
      | touch | /mnt/nfs/nfs_testfile |
    Then the step should fail
    And the output should contain:
      | Permission denied |

