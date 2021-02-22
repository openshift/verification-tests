Feature: vSphere test scenarios

  # @author jhou@redhat.com
  @admin
  Scenario Outline: Dynamically provision a vSphere volume with different disk formats
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/vsphere/storageclass.yml" where:
      | ["metadata"]["name"]         | storageclass-<%= project.name %> |
      | ["parameters"]["diskformat"] | <disk_format>                    |
    Then the step should succeed
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/vsphere/pvc.json" replacing paths:
        | ["metadata"]["name"]                                                   | pvc-<%= project.name %>          |
        | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | storageclass-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound

    # Testing volume mount and read/write
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/vsphere/pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["metadata"]["name"]                                         | mypod                   |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    When I execute on the pod:
      | touch | /mnt/vsphere/testfile |
    Then the step should succeed
    When I execute on the pod:
      | ls | -l | /mnt/vsphere |
    Then the step should succeed
    And the output should contain:
      | testfile |
      | 123456   |
    When I execute on the pod:
      | rm | /mnt/vsphere/testfile |
    Then the step should succeed

    # Testing execute permission
    Given I execute on the pod:
      | cp | /hello | /mnt/vsphere/hello |
    When I execute on the pod:
      | /mnt/vsphere/hello |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift Storage |

    # Testing reclaim policy
    Given I ensure "mypod" pod is deleted
    And I ensure "pvc-<%= project.name %>" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 60 seconds

    Examples:
      | disk_format      |
      | thin             | # @case_id OCP-13386
      | zeroedthick      | # @case_id OCP-13387
      | eagerzeroedthick | # @case_id OCP-13388

  # @author jhou@redhat.com
  # @case_id OCP-13389
  @admin
  Scenario: Dynamically provision a vSphere volume with invalid disk format
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/vsphere/storageclass.yml" where:
      | ["metadata"]["name"]         | storageclass-<%= project.name %> |
      | ["parameters"]["diskformat"] | newformat                        |
    Then the step should succeed

    Given I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/vsphere/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %>          |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | storageclass-<%= project.name %> |
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/pvc-<%= project.name %> |
    Then the output should contain:
      | Pending |
      | Failed  |
    """

