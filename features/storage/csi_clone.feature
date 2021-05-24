Feature: CSI clone testing related feature
  """
  This test can only work on a Cluster which has CSI driver deployed, OSP has csi deploy by default from 4.7. 
  From 4.7, OSP CSI driver was installed by default. Its storage class name is standard-csi.
  Use "oc get sc" can find all deployed stroage class.
  """
  
  # @author jianl@redhat.com
  # @case_id OCP-27615
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

    # Clone mypvc-ori with 3Gi size
    Given I obtain test data file "storage/csi/pvc-clone.yaml"
    When I create a dynamic pvc from "pvc-clone.yaml" replacing paths:
      | ["metadata"]["name"]                         | mypvc-clone  |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 3Gi          |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-clone |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-clone |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local  |
    Then the step should succeed
    Given the pod named "mypod-clone" becomes ready
    And the "mypvc-clone" PVC becomes :bound 
    Given the expression should be true> pv(pvc("mypvc-clone").volume_name).capacity_raw(cached: false) == "3Gi"
    When I execute on the "mypod-clone" pod:
      | sh | -c | ls /mnt/local/testfile |
    Then the step should succeed
    When I execute on the "mypod-clone" pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "clone test"
    # Need update when the filesystem is also 3Gi size(BZ) 

  # @author wduan@redhat.com
  # @case_id OCP-27690
  Scenario: [Cinder CSI Clone] Clone a pvc with capacity less than original pvc will fail
    Given I have a project
    # Create mypvc-ori with 3Gi size
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc-ori    |
      | ["spec"]["storageClassName"]                 | standard-csi |
      | ["spec"]["resources"]["requests"]["storage"] | 3Gi          |
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
    Given 30 seconds have passed
    And the "mypvc-clone" PVC status is :pending
    When I run the :describe client command with:
      | resource | pvc         |
      | name     | mypvc-clone |
    Then the step should succeed
    And the output should match:
      | ProvisioningFailed                                                                     |
      | new PVC request must be greater than or equal in size to the specified PVC data source |
