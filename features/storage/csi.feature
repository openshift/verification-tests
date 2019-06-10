Feature: CSI testing related feature

  # @author wehe@redhat.com
  # @case_id OCP-21804
  @admin
  @destructive
  Scenario: Deploy a cinder csi driver and test
    Given I deploy "cinder" driver using csi
    And I register clean-up steps:
    """
    I cleanup "cinder" csi driver
    """
    And I create storage class for "cinder" csi driver
    And I checked "cinder" csi driver is running
    And I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"] | cinder-csi              |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | pod-<%= project.name %> |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/cinder             |
    Then the step should succeed
    Given the pod named "pod-<%= project.name %>" becomes ready
    When I execute on the pod:
      | ls | -ld | /mnt/cinder/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/cinder/testfile |
    Then the step should succeed
    When I execute on the pod:
      | cp | /hello | /mnt/cinder/ |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/cinder/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"
