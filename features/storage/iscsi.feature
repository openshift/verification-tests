Feature: ISCSI volume plugin testing

  # @author jhou@redhat.com
  # @case_id OCP-9638
  @admin
  @destructive
  Scenario: OCP-9638 ISCSI volume security test
    Given I have a iSCSI setup in the environment
    And I have a project

    And admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/docker-iscsi/master/pv-rwo.json" where:
      | ["metadata"]["name"]              | pv-iscsi-<%= project.name %> |
      | ["spec"]["iscsi"]["targetPortal"] | <%= cb.iscsi_ip %>:3260      |
    And I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/docker-iscsi/master/pvc-rwo.json" replacing paths:
      | ["metadata"]["name"]   | pvc-iscsi-<%= project.name %> |
      | ["spec"]["volumeName"] | pv-iscsi-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-iscsi-<%= project.name %>" PVC becomes bound to the "pv-iscsi-<%= project.name %>" PV

    # Create tester pod
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/docker-iscsi/master/pod.json" replacing paths:
      | ["metadata"]["name"]                                         | iscsi-<%= project.name %>     |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-iscsi-<%= project.name %> |
    Then the step should succeed
    And the pod named "iscsi-<%= project.name %>" becomes ready

    # Verify uid and gid are correct
    When I execute on the "iscsi-<%= project.name %>" pod:
      | id | -u |
    Then the output should contain:
      | 101010 |
    When I execute on the "iscsi-<%= project.name %>" pod:
      | id | -G |
    Then the output should contain:
      | 123456 |

    # Verify mount directory has supplemental groups set properly
    # Verify SELinux context is set properly
    When I execute on the "iscsi-<%= project.name %>" pod:
      | ls | -lZd | /mnt/iscsi |
    Then the output should match:
      | 123456                                   |
      | (svirt_sandbox_file_t\|container_file_t) |
      | s0:c2,c13                                |

    # Verify created file belongs to supplemental group
    Given I execute on the "iscsi-<%= project.name %>" pod:
      | touch | /mnt/iscsi/iscsi_testfile |
    When I execute on the "iscsi-<%= project.name %>" pod:
      | ls | -l | /mnt/iscsi/iscsi_testfile |
    Then the output should contain:
      | 123456 |
    When I execute on the pod:
      | cp | /hello | /mnt/iscsi |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/iscsi/hello |
    Then the step should succeed

