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
