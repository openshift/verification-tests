Feature: ResourceQuata for storage

  # @author jhou@redhat.com
  # @case_id OCP-14173
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @rosa @osd_ccs @aro
  @vsphere-ipi @openstack-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  @storage
  Scenario: OCP-14173:Storage Requested storage can not exceed the namespace's storage quota
    Given I have a project with proper privilege
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project

    # Admin could create ResourceQuata
    Given I obtain test data file "storage/misc/quota-pvc-storage.yaml"
    When I run oc create over "quota-pvc-storage.yaml" replacing paths:
      | ["spec"]["hard"]["persistentvolumeclaims"] | 5    |
      | ["spec"]["hard"]["requests.storage"]       | 12Gi |
    Then the step should succeed

    # Consume 9Gi storage in the namespace
    And I run the steps 3 times:
    """
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-#{ cb.i } |
      | ["spec"]["resources"]["requests"]["storage"] | 3Gi           |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-#{ cb.i }   |
      | ["metadata"]["name"]                                         | mypod-#{ cb.i } |
    Then the step should succeed
    And the pod named "mypod-#{ cb.i}" becomes ready
    """

    # Try to exceed the 12Gi storage
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["resources"]["requests"]["storage"] | 4Gi   |
    Then the step should fail
    And the output should contain:
      | exceeded quota                 |
      | requests.storage=4Gi           |
      | used: requests.storage=9Gi     |
      | limited: requests.storage=12Gi |

    # Try to exceed total number of PVCs
    And I run the steps 2 times:
    """
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvci-#{ cb.i } |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi            |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvci-#{ cb.i }   |
      | ["metadata"]["name"]                                         | mypodi-#{ cb.i } |
    Then the step should succeed
    And the pod named "mypodi-#{ cb.i }" becomes ready
    """
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi   |
    Then the step should fail
    And the output should contain:
      | exceeded quota                      |
      | requested: persistentvolumeclaims=1 |
      | used: persistentvolumeclaims=5      |
      | limited: persistentvolumeclaims=5   |

  # @author jhou@redhat.com
  # @case_id OCP-14382
  @admin
  @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @rosa @osd_ccs @aro
  @vsphere-ipi @openstack-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  @storage
  Scenario: OCP-14382:Storage Setting quota for a StorageClass
    Given I have a project
    Given admin clones storage class "sc-<%= project.name %>" from ":default" with:
      | ["volumeBindingMode"] | Immediate |
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project

    # Add ResourceQuata for the StorageClass
    Given I obtain test data file "storage/misc/quota_for_storageclass.yml"
    When I run oc create over "quota_for_storageclass.yml" replacing paths:
      | ["spec"]["hard"]["sc-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims"] | 3    |
      | ["spec"]["hard"]["sc-<%= project.name %>.storageclass.storage.k8s.io/requests.storage"]       | 10Mi |
    Then the step should succeed

    # Consume 8Mi storage in the namespace
    And I run the steps 2 times:
    """
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-#{ cb.i }          |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 4Mi                    |
    Then the step should succeed
    And the "pvc-#{ cb.i }" PVC becomes :bound
    And admin ensures "#{ pvc.volume_name }" pv is deleted after scenario
    """

    # Try to exceed the 10Mi storage
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc                  |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 4Mi                    |
    Then the step should fail
    And the output should contain:
      | exceeded quota                                                                     |
      | requested: sc-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=4Mi |
      | used: sc-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=8Mi      |
      | limited: sc-<%= project.name %>.storageclass.storage.k8s.io/requests.storage=10Mi  |

    # Try to exceed total number of PVCs
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvcnew                 |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Mi                    |
    Then the step should succeed
    And the "pvcnew" PVC becomes :bound
    And admin ensures "<%= pvc('pvcnew').volume_name %>" pv is deleted after scenario

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvcnew2                |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Mi                    |
    Then the step should fail
    And the output should contain:
      | exceeded quota                                                                         |
      | requested: sc-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=1 |
      | used: sc-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=3      |
      | limited: sc-<%= project.name %>.storageclass.storage.k8s.io/persistentvolumeclaims=3   |

    # StorageClass without quota should not be limited
    Given admin clones storage class "sc1-<%= project.name %>" from ":default" with:
      | ["volumeBindingMode"] | Immediate |
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc1                   |
      | ["spec"]["storageClassName"]                 | sc1-<%= project.name %>  |
      | ["spec"]["resources"]["requests"]["storage"] | 11Mi                     |
    Then the step should succeed
    And the "mypvc1" PVC becomes :bound
    Given I ensure "mypvc1" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

