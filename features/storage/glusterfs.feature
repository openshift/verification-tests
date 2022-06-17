Feature: Storage of GlusterFS plugin testing

  # @author chaoyang@redhat.com
  # @case_id OCP-9707
  @admin
  @destructive
  Scenario: OCP-9707 Glusterfs volume security testing
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

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/endpoints.json" replacing paths:
      | ["metadata"]["name"]                 | glusterfs-cluster             |
      | ["subsets"][0]["addresses"][0]["ip"] | <%= service("glusterd").ip %> |
      | ["subsets"][0]["ports"][0]["port"]   | 24007                         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/security/gluster_pod_sg.json" replacing paths:
      | ["metadata"]["name"] | glusterpd-<%= project.name %> |
    Then the step should succeed

    Given the pod named "glusterpd-<%= project.name %>" becomes ready
    And I execute on the "glusterpd-<%= project.name %>" pod:
      | ls | /mnt/glusterfs |
    Then the step should succeed

    And I execute on the "glusterpd-<%= project.name %>" pod:
      | touch | /mnt/glusterfs/gluster_testfile |
    Then the step should succeed

    # Testing execute permission
    Given I execute on the "glusterpd-<%= project.name %>" pod:
      | cp | /hello | /mnt/glusterfs/hello |
    When I execute on the "glusterpd-<%= project.name %>" pod:
      | /mnt/glusterfs/hello |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift Storage |

    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/security/gluster_pod_sg.json" replacing paths:
      | ["metadata"]["name"]                              | glusterpd-negative-<%= project.name %> |
      | ["spec"]["securityContext"]["supplementalGroups"] | [123460]                               |
    Then the step should succeed
    Given the pod named "glusterpd-negative-<%= project.name %>" becomes ready
    And I execute on the "glusterpd-negative-<%= project.name %>" pod:
      | ls | /mnt/glusterfs |
    Then the step should fail
    Then the outputs should contain:
      | Permission denied  |

    And I execute on the "glusterpd-negative-<%= project.name %>" pod:
      | touch | /mnt/glusterfs/gluster_testfile |
    Then the step should fail
    Then the outputs should contain:
      | Permission denied  |

  # @author jhou@redhat.com
  # @case_id OCP-10267
  @admin
  Scenario: OCP-10267 Dynamically provision a GlusterFS volume
    Given I have a StorageClass named "glusterprovisioner"
    And I have a project

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1               |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | glusterprovisioner |
    Then the step should succeed
    And the "pvc1" PVC becomes :bound
    And admin ensures "<%= pvc('pvc1').volume_name %>" pv is deleted after scenario

    # Switch to admin so as to create privileged pod
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/dynamic-provisioning/pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1 |
    Then the step should succeed
    And the pod named "gluster" status becomes :running

    # Test creating files
    When I execute on the "gluster" pod:
      | touch | /mnt/gluster/gluster_testfile |
    Then the step should succeed
    When I execute on the "gluster" pod:
      | ls | /mnt/gluster/ |
    Then the output should contain:
      | gluster_testfile |

    # Testing execute permission
    Given I execute on the "gluster" pod:
      | cp | /hello | /mnt/gluster/hello |
    When I execute on the "gluster" pod:
      | /mnt/gluster/hello |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift Storage |

  # @author jhou@redhat.com
  # @case_id OCP-10266
  @admin
  Scenario: OCP-10266 Reclaim a provisioned GlusterFS volume
    Given I have a StorageClass named "glusterprovisioner"
    And I have a project

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | glusterprovisioner      |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Delete"

    # Test auto deleting PV
    Given I run the :delete client command with:
      | object_type       | pvc                     |
      | object_name_or_id | pvc-<%= project.name %> |
    And I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 60 seconds

  # @author jhou@redhat.com
  # @case_id OCP-10356
  @admin
  Scenario: OCP-10356 Dynamically provision a GlusterFS volume using heketi secret
    # A StorageClass preconfigured on the test env
    Given I have a StorageClass named "glusterprovisioner1"
    And admin checks that the "heketi-secret" secret exists in the "default" project
    And I have a project

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1                |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | glusterprovisioner1 |
    Then the step should succeed
    And the "pvc1" PVC becomes :bound
    And admin ensures "<%= pvc('pvc1').volume_name %>" pv is deleted after scenario

    # Switch to admin so as to create privileged pod
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/dynamic-provisioning/pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1 |
    Then the step should succeed
    And the pod named "gluster" status becomes :running

  # @author jhou@redhat.com
  # @case_id OCP-10554
  @admin
  Scenario: OCP-10554 Pods should be assigned a valid GID using GlusterFS dynamic provisioner
    Given I have a StorageClass named "glusterprovisioner"
    And I have a project

    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/storageclass_using_key.yaml" where:
      | ["metadata"]["name"]      | storageclass-<%= project.name %>                                 |
      | ["parameters"]["resturl"] | <%= storage_class("glusterprovisioner").rest_url %> |
      | ["parameters"]["gidMin"]  | 3333                                                             |
      | ["parameters"]["gidMax"]  | 33333                                                            |
    Then the step should succeed
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1                             |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | storageclass-<%= project.name %> |
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
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/dynamic-provisioning/pod_gid.json" replacing paths:
      | ["metadata"]["name"]                                         | pod-<%= project.name %> |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1                    |
    Then the step should succeed
    Given the pod named "pod-<%= project.name %>" becomes ready
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
    Given I ensure "pod-<%= project.name %>" pod is deleted
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/gluster/dynamic-provisioning/pod_gid.json" replacing paths:
      | ["metadata"]["name"]                                         | pod1-<%= project.name %> |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc1                     |
      | ["spec"]["securityContext"]["supplementalGroups"]            | [3333]                   |
    Then the step should succeed
    Given the pod named "pod1-<%= project.name %>" becomes ready
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

  # @author jhou@redhat.com
  # @case_id OCP-10354
  @admin
  Scenario: OCP-10354 Provisioned GlusterFS volume should be replicated with 3 replicas
    Given I have a StorageClass named "glusterprovisioner"
    And I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gluster/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1               |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | glusterprovisioner |
    Then the step should succeed
    And the "pvc1" PVC becomes :bound
    And admin ensures "<%= pvc('pvc1').volume_name %>" pv is deleted after scenario

    # Verify by default it's replicated with 3 replicas
    Given I save volume id from PV named "<%= pvc('pvc1').volume_name %>" in the :volumeID clipboard
    And I run commands on the StorageClass "glusterprovisioner" backing host:
      | heketi-cli --server http://127.0.0.1:9991 --user admin --secret test volume info <%= cb.volumeID %> |
    Then the output should contain:
      | Durability Type: replicate |
      | Distributed+Replica: 3     |

