Feature: vSphere test scenarios

  # @author jhou@redhat.com
  @admin
  @smoke
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Dynamically provision a vSphere volume with different disk formats
    Given I have a project
    Given I obtain test data file "storage/vsphere/storageclass.yml"
    When admin creates a StorageClass from "storageclass.yml" where:
      | ["metadata"]["name"]         | storageclass-<%= project.name %> |
      | ["parameters"]["diskformat"] | <disk_format>                    |
    Then the step should succeed
    Given I obtain test data file "storage/vsphere/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
        | ["metadata"]["name"]         | mypvc          |
        | ["spec"]["storageClassName"] | storageclass-<%= project.name %> |
    Then the step should succeed
    And the "mypvc" PVC becomes :bound

    # Testing volume mount and read/write
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/vsphere/pod.json"
    When I run oc create over "pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
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
    And I ensure "mypvc" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 60 seconds

    @vsphere-ipi
    @vsphere-upi
    @upgrade-sanity
    @singlenode
    @proxy @noproxy @disconnected @connected
    @heterogeneous @arm64 @amd64
    Examples:
      | case_id   | disk_format      |
      | OCP-13386 | thin             | # @case_id OCP-13386
      | OCP-13387 | zeroedthick      | # @case_id OCP-13387
      | OCP-13388 | eagerzeroedthick | # @case_id OCP-13388

  # @author jhou@redhat.com
  # @case_id OCP-13389
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi
  @vsphere-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-13389:Storage Dynamically provision a vSphere volume with invalid disk format
    Given I have a project
    Given I obtain test data file "storage/vsphere/storageclass.yml"
    When admin creates a StorageClass from "storageclass.yml" where:
      | ["metadata"]["name"]         | storageclass-<%= project.name %> |
      | ["parameters"]["diskformat"] | newformat                        |
    Then the step should succeed

    Given I obtain test data file "storage/vsphere/pvc.json"
    Given I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc          |
      | ["spec"]["storageClassName"] | storageclass-<%= project.name %> |
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/mypvc |
    Then the output should contain:
      | Pending |
      | Failed  |
    """

