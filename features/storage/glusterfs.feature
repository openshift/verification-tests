Feature: Storage of GlusterFS plugin testing

  # @author chaoyang@redhat.com
  # @case_id OCP-9707
  @admin
  @destructive
  Scenario: Glusterfs volume security testing
    Given I have a project
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project

    Given I have a Gluster service in the project
    When I execute on the "glusterd" pod:
      | chown | -R | root:123456 | /vol |
    Then the step should succeed
    When I execute on the "glusterd" pod:
      | chmod | -R | 770 | /vol |
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/gluster/endpoints.json" replacing paths:
      | ["metadata"]["name"]                 | glusterfs-cluster             |
      | ["subsets"][0]["addresses"][0]["ip"] | <%= service("glusterd").ip %> |
      | ["subsets"][0]["ports"][0]["port"]   | 24007                         |
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/gluster/security/gluster_pod_sg.json" replacing paths:
      | ["metadata"]["name"] | mypod |
    Then the step should succeed

    Given the pod named "mypod" becomes ready
    And I execute on the pod:
      | ls | /mnt/glusterfs |
    Then the step should succeed

    And I execute on the pod:
      | touch | /mnt/glusterfs/gluster_testfile |
    Then the step should succeed

    # Testing execute permission
    Given I execute on the pod:
      | cp | /hello | /mnt/glusterfs/hello |
    When I execute on the pod:
      | /mnt/glusterfs/hello |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift Storage |

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/gluster/security/gluster_pod_sg.json" replacing paths:
      | ["metadata"]["name"]                              | glusterpd-negative |
      | ["spec"]["securityContext"]["supplementalGroups"] | [123460]                               |
    Then the step should succeed
    Given the pod named "glusterpd-negative" becomes ready
    And I execute on the pod:
      | ls | /mnt/glusterfs |
    Then the step should fail
    Then the outputs should contain:
      | Permission denied  |

    And I execute on the pod:
      | touch | /mnt/glusterfs/gluster_testfile |
    Then the step should fail
    Then the outputs should contain:
      | Permission denied  |

  # @author jhou@redhat.com
  # @case_id OCP-10554
  @admin
  Scenario: Pods should be assigned a valid GID using GlusterFS dynamic provisioner
    Given I have a StorageClass named "glusterprovisioner"
    And I have a project

    When admin creates a StorageClass from "<%= BushSlicer::HOME %>/testdata/storage/gluster/dynamic-provisioning/storageclass_using_key.yaml" where:
      | ["metadata"]["name"]      | storageclass-<%= project.name %>                                 |
      | ["parameters"]["resturl"] | <%= storage_class("glusterprovisioner").rest_url %> |
      | ["parameters"]["gidMin"]  | 3333                                                             |
      | ["parameters"]["gidMax"]  | 33333                                                            |
    Then the step should succeed
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]         | pvc1                             |
      | ["spec"]["storageClassName"] | storageclass-<%= project.name %> |
    Then the step should succeed
    And the "pvc1" PVC becomes :bound
    And admin ensures "<%= pvc('pvc1').volume_name %>" pv is deleted after scenario

    # Verify PV is annotated with inhitial gidMin 3333
    When I run the :get admin command with:
      | resource      | pv                                 |
      | resource_name | <%= pvc.volume_name %> |
      | o             | yaml                               |
    Then the output should contain:
      | pv.beta.kubernetes.io/gid: "3333" |

    # Verify Pod is assigned gid 3333
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/gluster/dynamic-provisioning/pod_gid.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1                    |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    When I execute on the pod:
      | id | -G |
    Then the output should contain:
      | 3333 |
    When I execute on the pod:
      | ls | -ld | /mnt/gluster |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/gluster/tc508054 |
    Then the step should succeed

    # Pod should work as well having its supplementalGroups set to 3333 explicitly
    Given I ensure "mypod" pod is deleted
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/gluster/dynamic-provisioning/pod_gid.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod1 |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1                     |
      | ["spec"]["securityContext"]["supplementalGroups"]            | [3333]                   |
    Then the step should succeed
    Given the pod named "mypod1" becomes ready
    When I execute on the pod:
      | id | -G |
    Then the output should contain:
      | 3333 |
    When I execute on the pod:
      | ls | -ld | /mnt/gluster |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/gluster/tc508054 |
    Then the step should succeed
