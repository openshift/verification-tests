Feature: Storage of Ceph plugin testing

  # @author jhou@redhat.com
  # @case_id OCP-10485
  @admin
  Scenario: Dynamically provision Ceph RBD volumes
    Given I have a StorageClass named "cephrbdprovisioner"
    And admin checks that the "cephrbd-secret" secret exists in the "default" project

    And I run the :get admin command with:
      | resource      | secret         |
      | resource_name | cephrbd-secret |
      | namespace     | default        |
      | o             | yaml           |
    # The user secret is retrieved from "cephrbd-secret" for pod mounts
    And evaluation of `@result[:parsed]["data"]["key"]` is stored in the :secret_key clipboard

    Given I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/rbd/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | cephrbdprovisioner      |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    # Switch to admin so as to create pod with desired FSGroup and SElinux levels
    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    And I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/rbd/dynamic-provisioning/user_secret.yaml" replacing paths:
      | ["data"]["key"] | <%= cb.secret_key %> |
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/rbd/dynamic-provisioning/pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the pod named "rbdpd" becomes ready

    # Test creating files
    When I execute on the pod:
      | ls | -lZd | /mnt/rbd/ |
    Then the output should match:
      | 123456                                   |
      | (svirt_sandbox_file_t\|container_file_t) |

    When I execute on the pod:
      | touch | /mnt/rbd/rbd_testfile |
    Then the step should succeed

    When I execute on the pod:
      | ls | -l | /mnt/rbd/rbd_testfile |
    Then the output should contain:
      | 123456 |

  # @author jhou@redhat.com
  # @case_id OCP-10268
  @admin
  Scenario: Dynamically provisioned rbd volumes should have correct capacity
    Given I have a StorageClass named "cephrbdprovisioner"
    # CephRBD provisioner needs secret, verify secret and StorageClass both exists
    And admin checks that the "cephrbd-secret" secret exists in the "default" project
    And I have a project

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/rbd/dynamic-provisioning/claim.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | cephrbdprovisioner      |
      | ["spec"]["resources"]["requests"]["storage"]                           | 9Gi                     |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    And the expression should be true> pvc.capacity == "9Gi"

