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