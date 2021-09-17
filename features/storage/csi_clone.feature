Feature: CSI clone testing related feature
  """
  This test can only work on a Cluster which has CSI driver deployed, OSP has csi deploy by default from 4.7. 
  From 4.7, OSP CSI driver was installed by default. Its storage class name is standard-csi.
  Use "oc get sc" can find all deployed stroage class.
  """
  
  # @author jianl@redhat.com
  # @case_id OCP-27615
  @4.9
  Scenario: Clone a PVC and verify data consistency
    # Step 1
    Given the master version >= "4.7"
    Given I have a project
    # Step 2
    When I obtain test data file "storage/csi/pod_pvc_sc.yaml"
    And I run the :create client command with:
      | f | pod_pvc_sc.yaml |
    Then the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound
    # Step 3
    Given 1 pod becomes ready with labels:
      | name=frontendhttp |
    When I execute on the pod:
      | sh | -c | echo "clone test" > /mnt/local/testfile |
    Then the step should succeed
    # Because the execution is too fast, we have to sync test file to avoid nothing to clone.
    When I execute on the pod:
      | sh | -c | sync -f /mnt/local/testfile |
    Then the step should succeed
    # Step 4
    When I obtain test data file "storage/csi/pod_clone.yaml"
    And I run the :create client command with:
      | f | pod_clone.yaml |
    Then the pod named "mypod-clone" becomes ready
    And the "mypvc-clone" PVC becomes :bound
    # Step 5
    Given 1 pod becomes ready with labels:
      | name=frontendhttp-clone |
    When I execute on the pod:
      | sh | -c | cat /mnt/local/testfile |
    Then the output should contain "clone test"
    When I execute on the pod:
      | sh | -c | echo "clone test" > /mnt/local/testfile_2nd |
    Then the step should succeed


  # @author wduan@redhat.com
  # @case_id OCP-27689
  @4.9
  Scenario: [Cinder CSI Clone] Clone a pvc with capacity greater than original pvc
    Given I have a project
    # Create mypvc-ori with 1Gi size
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc-ori    |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi          |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori  |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-ori" becomes ready
    When I execute on the pod:
      | sh | -c | echo "clone test" > /mnt/local/testfile |
    Then the step should succeed
    And I execute on the pod:
      | sh | -c | sync -f /mnt/local/testfile |
    Then the step should succeed

    # Clone mypvc-ori with 2Gi size
    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"]                         | mypvc-clone  |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 2Gi          |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-clone |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-clone |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local  |
    Then the step should succeed
    Given the pod named "mypod-clone" becomes ready
    And the "mypvc-clone" PVC becomes :bound 
    Given the expression should be true> pv(pvc("mypvc-clone").volume_name).capacity_raw(cached: false) == "2Gi"
    When I execute on the "mypod-clone" pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "clone test"
    # Need update when the filesystem is also 2Gi size(BZ: https://bugzilla.redhat.com/show_bug.cgi?id=1964210)

  # @author wduan@redhat.com
  # @case_id OCP-27690
  @4.9
  Scenario: [Cinder CSI Clone] Clone a pvc with capacity less than original pvc will fail
    Given I have a project
    # Create mypvc-ori with 2Gi size
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc-ori    |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 2Gi          |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori  |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed

    # Clone mypvc-ori with 1Gi size failed
    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"]                         | mypvc-clone  |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi          |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-clone |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-clone |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local  |
    Then the step should succeed
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc         |
      | name     | mypvc-clone |
    Then the step should succeed
    And the output should match:
      | ProvisioningFailed                                                                     |
      | new PVC request must be greater than or equal in size to the specified PVC data source |
    """


  # @author wduan@redhat.com
  # @case_id OCP-30315
  @4.9
  Scenario: [Cinder CSI clone] Clone a pvc with block VolumeMode successfully
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc-ori    |
      | ["spec"]["storageClassName"] | standard-csi |
      | ["spec"]["volumeMode"]       | Block        |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod-with-block-volume.yaml"
    When I run oc create over "pod-with-block-volume.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori   |
      | ["spec"]["containers"][0]["volumeDevices"][0]["devicePath"]  | /dev/dblock |
    Then the step should succeed
    And the pod named "mypod-ori" becomes ready
    When I execute on the pod:
      | /bin/dd | if=/dev/zero | of=/dev/dblock | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | echo "test data" > /dev/dblock |
    Then the step should succeed
    When I execute on the pod:
      | sync |
    Then the step should succeed

    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"]                         | mypvc-clone  |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi          |
      | ["spec"]["volumeMode"]                       | Block        |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod-with-block-volume.yaml"
    When I run oc create over "pod-with-block-volume.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-clone |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-clone |
      | ["spec"]["containers"][0]["volumeDevices"][0]["devicePath"]  | /dev/dblock |
    Then the step should succeed
    Given the pod named "mypod-clone" becomes ready
    When I execute on the pod:
      | /bin/dd | if=/dev/dblock | of=/tmp/testfile | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | cat /tmp/testfile |
    Then the step should succeed
    And the output should contain "test data"

  # @author wduan@redhat.com
  # @case_id OCP-27617
  @admin
  @destructive
  @4.9
  Scenario: [Cinder CSI Clone] Clone a pvc with default storageclass
    Given default storage class is patched to non-default
    And admin clones storage class "my-csi-default" from "standard-csi" with:
      | ["metadata"]["name"] | my-csi-default |
    When I run the :patch admin command with:
      | resource      | storageclass                                                                           |
      | resource_name | my-csi-default                                                                         |
      | p             | {"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}} |

    # Create mypvc-ori without sc specified
    Given I have a project
    When I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc-ori |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori  |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-ori" becomes ready
    When I execute on the pod:
      | sh | -c | echo "clone test" > /mnt/local/testfile |
    Then the step should succeed
    And I execute on the pod:
      | sh | -c | sync -f /mnt/local/testfile |
    Then the step should succeed

    # Clone mypvc-ori without sc specified
    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"] | mypvc-clone  |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-clone |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-clone |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local  |
    Then the step should succeed
    Given the pod named "mypod-clone" becomes ready
    And the "mypvc-clone" PVC becomes :bound
    When I execute on the "mypod-clone" pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "clone test"


  # @author wduan@redhat.com
  # @case_id OCP-27686
  @admin
  @4.9
  Scenario: [Cinder CSI Clone] Clone a pvc with different storage class is failed
    # Create mypvc-ori with sc1
    Given I have a project
    When admin clones storage class "sc-<%= project.name %>-1" from "standard-csi" with:
      | ["volumeBindingMode"] | Immediate |
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc-ori                |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>-1 |
    Then the step should succeed

    # Clone mypvc-ori with sc2
    When admin clones storage class "sc-<%= project.name %>-2" from "standard-csi" with:
      | ["volumeBindingMode"] | Immediate |
    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc-clone              |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>-2 |
    Then the step should succeed

    Given I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc         |
      | name     | mypvc-clone |
    Then the step should succeed
    And the output should match:
      | ProvisioningFailed                                                                |
      | the source PVC and destination PVCs must be in the same storage class for cloning |
    """

