Feature: ISCSI volume plugin testing

  # @author jhou@redhat.com
  # @case_id OCP-9638
  @admin
  @destructive
  Scenario: ISCSI volume security test
    Given I have a iSCSI setup in the environment
    And I have a project
    Given I obtain test data file "storage/iscsi/pv-rwo.json"
    When admin creates a PV from "pv-rwo.json" where:
      | ["metadata"]["name"]               | pv-<%= project.name %>        |
      | ["spec"]["iscsi"]["targetPortal"]  | <%= cb.iscsi_ip %>:3260       |
      | ["spec"]["iscsi"]["initiatorName"] | iqn.2016-04.test.com:test.img |
      | ["spec"]["storageClassName"]       | sc-<%= project.name %>        |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV
    # Create tester pod
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/iscsi/pod-security.json"
    When I run oc create over "pod-security.json" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    # Verify uid and gid are correct
    When I execute on the pod:
      | id | -u |
    Then the output should contain:
      | 101010 |
    When I execute on the pod:
      | id | -G |
    Then the output should contain:
      | 123456 |
    # Verify mount directory has supplemental groups set properly
    # Verify SELinux context is set properly
    When I execute on the pod:
      | ls | -lZd | /mnt/iscsi |
    Then the output should match:
      | 123456                                   |
      | (svirt_sandbox_file_t\|container_file_t) |
      | s0:c2,c13                                |
    # Verify created file belongs to supplemental group
    Given I execute on the pod:
      | touch | /mnt/iscsi/iscsi_testfile |
    When I execute on the pod:
      | ls | -l | /mnt/iscsi/iscsi_testfile |
    Then the output should contain:
      | 123456 |
    When I execute on the pod:
      | cp | /hello | /mnt/iscsi |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/iscsi/hello |
    Then the step should succeed
