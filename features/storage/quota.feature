Feature: ResourceQuata for storage

  # @author jhou@redhat.com
  # @case_id OCP-14173
  @admin
  Scenario: OCP-14173 Requested storage can not exceed the namespace's storage quota
    Given I have a project
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project

    # Admin could create ResourceQuata
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/quota-pvc-storage.yaml" replacing paths:
      | ["spec"]["hard"]["persistentvolumeclaims"] | 5    |
      | ["spec"]["hard"]["requests.storage"]       | 12Gi |
    Then the step should succeed

    # Consume 9Gi storage in the namespace
    And I run the steps 3 times:
    """
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                    | pvc-#{ cb.i } |
      | ["metadata"]["annotations"]["volume.alpha.kubernetes.io/storage-class"] | foo           |
      | ["spec"]["resources"]["requests"]["storage"]                            | 3Gi           |
    Then the step should succeed
    And the "pvc-#{ cb.i }" PVC becomes :bound
    """

    # Try to exceed the 12Gi storage
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                    | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.alpha.kubernetes.io/storage-class"] | foo                     |
      | ["spec"]["resources"]["requests"]["storage"]                            | 4Gi                     |
    Then the step should fail
    And the output should contain:
      | exceeded quota                 |
      | requests.storage=4Gi           |
      | used: requests.storage=9Gi     |
      | limited: requests.storage=12Gi |

    # Try to exceed total number of PVCs
    And I run the steps 2 times:
    """
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                    | pvci-#{ cb.i } |
      | ["metadata"]["annotations"]["volume.alpha.kubernetes.io/storage-class"] | foo            |
      | ["spec"]["resources"]["requests"]["storage"]                            | 1Gi            |
    Then the step should succeed
    And the "pvc-#{ cb.i }" PVC becomes :bound
    """

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                    | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.alpha.kubernetes.io/storage-class"] | foo                     |
      | ["spec"]["resources"]["requests"]["storage"]                            | 1Gi                     |
    Then the step should fail
    And the output should contain:
      | exceeded quota                      |
      | requested: persistentvolumeclaims=1 |
      | used: persistentvolumeclaims=5      |
      | limited: persistentvolumeclaims=5   |

  # @author jhou@redhat.com
  # @case_id OCP-14382
  @admin
  Scenario: OCP-14382 Setting quota for a StorageClass
    Given I have a project
    And I have a nfs-provisioner service in the project
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project

    # Add ResourceQuata for the StorageClass
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/quota_for_storageclass.yml" replacing paths:
      | ["spec"]["hard"]["nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims"] | 3    |
      | ["spec"]["hard"]["nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/requests.storage"]       | 10Mi |
    Then the step should succeed

    # Consume 8Mi storage in the namespace
    And I run the steps 2 times:
    """
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs-provisioner/nfsdyn-pvc.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-#{ cb.i }                       |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | nfs-provisioner-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]                           | 4Mi                                 |
    Then the step should succeed
    And the "pvc-#{ cb.i }" PVC becomes :bound
    And admin ensures "#{ pvc.volume_name }" pv is deleted after scenario
    """

    # Try to exceed the 10Mi storage
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs-provisioner/nfsdyn-pvc.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %>             |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | nfs-provisioner-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]                           | 4Mi                                 |
    Then the step should fail
    And the output should contain:
      | exceeded quota                                                                                  |
      | requested: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=4Mi |
      | used: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=8Mi      |
      | limited: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=10Mi  |

    # Try to exceed total number of PVCs
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs-provisioner/nfsdyn-pvc.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvcnew                              |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | nfs-provisioner-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]                           | 1Mi                                 |
    Then the step should succeed
    And the "pvcnew" PVC becomes :bound
    And admin ensures "<%= pvc('pvcnew').volume_name %>" pv is deleted after scenario

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/nfs-provisioner/nfsdyn-pvc.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvcnew2                             |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | nfs-provisioner-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]                           | 1Mi                                 |
    Then the step should fail
    And the output should contain:
      | exceeded quota                                                                                      |
      | requested: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=1 |
      | used: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=3      |
      | limited: nfs-provisioner-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=3   |

    # StorageClass without quota should not be limited
    Given admin clones storage class "nfs-provisioner1-<%= project.name %>" from "nfs-provisioner-<%= project.name %>" with:
      | | |
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1-<%= project.name %>             |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | nfs-provisioner1-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]                           | 11Mi                                 |
    Then the step should succeed
    And the "pvc1-<%= project.name %>" PVC becomes :bound
    Given I ensure "pvc1-<%= project.name %>" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

