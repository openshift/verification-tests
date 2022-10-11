Feature: ONLY ONLINE Storage related scripts in this file

  # @author bingli@redhat.com
  # @case_id OCP-9967
  Scenario: OCP-9967 Delete pod with mounting error
    Given I have a project
    Given I obtain test data file "online/pod_volumetest.json"
    When I run the :create client command with:
      | f | pod_volumetest.json |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pod |
    Then the output should match:
      | volumetest\\s+0/1.+[eE]rror.+ |
    """
    When I run the :describe client command with:
      | resource | pod        |
      | name     | volumetest |
    Then the step should succeed
    And the output should contain:
      | mkdir /var/lib/docker/volumes/ |
      | permission denied              |
    When I run the :delete client command with:
      | object_type       | pod        |
      | object_name_or_id | volumetest |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pod |
    Then the output should not contain:
      | volumetest |
    """

  # @author yasun@redhat.com
  # @case_id OCP-9809
  Scenario: OCP-9809 Pod should not create directories within /var/lib/docker/volumes/ on nodes
    Given I have a project
    Given I obtain test data file "online/pod_volumetest.json"
    When I run the :create client command with:
      | f | pod_volumetest.json |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pod |
    Then the output should match:
      | volumetest\\s+0/1.+[eE]rror.+ |
    """
    When I run the :describe client command with:
      | resource | pod        |
      | name     | volumetest |
    Then the step should succeed
    And the output should contain:
      | mkdir /var/lib/docker/volumes/ |
      | permission denied              |

  # @author yasun@redhat.com
  # @case_id OCP-13108
  Scenario: OCP-13108 Basic user could not get pv object info
    Given I have a project
    Given I obtain test data file "storage/ebs/claim.json"
    When I run oc create over "claim.json" replacing paths:
      | ["metadata"]["name"]                           | ebsc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"]   | 1Gi                      |
    And the step should succeed
    And the "ebsc-<%= project.name %>" PVC becomes :bound
    And evaluation of `pvc("ebsc-#{project.name}").volume_name(user: user)` is stored in the :pv_name clipboard

    When I run the :describe client command with:
      | resource          | pvc                      |
      | name              | ebsc-<%= project.name %> |
    And the step should succeed

    When I run the :get client command with:
      | resource          | pv                |
      | resource_name     | <%= cb.pv_name %> |
    And the step should fail
    And the output should contain:
      | Forbidden     |
      | cannot get    |

    When I run the :describe client command with:
      | resource          | pv                |
      | name              | <%= cb.pv_name %> |
    And the step should fail
    And the output should contain:
      | Forbidden     |
      | cannot get    |

    When I run the :delete client command with:
      | object_type       | pv                |
      | object_name_or_id | <%= cb.pv_name %> |
    And the step should fail
    And the output should contain:
      | Forbidden     |
      | cannot delete |

  # @author yasun@redhat.com
  # @case_id OCP-9923
  Scenario: OCP-9923 Claim requesting to get the maximum capacity
    Given I have a project
    Given I obtain test data file "online/dynamic_persistent_volumes/pvc-equal.yaml"
    When I run the :create client command with:
      | f | pvc-equal.yaml |
    Then the step should succeed
    And the "claim-equal-limit" PVC becomes :bound
    And I ensure "claim-equal-limit" pvc is deleted

    Given I obtain test data file "online/dynamic_persistent_volumes/pvc-over.yaml"
    When I run the :create client command with:
      | f | pvc-over.yaml  |
    Then the step should fail
    And the output should contain:
      | Forbidden                                              |
      | maximum storage usage per PersistentVolumeClaim is 1Gi |
      | request is 5Gi                                         |

    Given I obtain test data file "online/dynamic_persistent_volumes/pvc-less.yaml"
    When I run the :create client command with:
      | f | pvc-less.yaml  |
    Then the step should fail
    And the output should contain:
      | Forbidden                                              |
      | minimum storage usage per PersistentVolumeClaim is 1Gi |
      | request is 600Mi                                       |

  # @author yasun@redhat.com
  # @case_id OCP-10529
  Scenario Outline: create pvc with annotation in aws
    Given I have a project
    Given I obtain test data file "online/dynamic_persistent_volumes/<pvc-name>.json"
    When I run the :create client command with:
      | f | <pvc-name>.json |
    Then the step should succeed
    And the "<pvc-name>" PVC becomes :<status>
    When I run the :describe client command with:
      | resource | pvc        |
      | name     | <pvc-name> |
    Then the step should succeed
    And the output should match:
      | <output> |
    Then I run the :delete client command with:
      | object_type       | pvc        |
      | object_name_or_id | <pvc-name> |
    Then the step should succeed

    Examples: create pvc with annotation in aws
      |  pvc-name               | status  | output                                                                     |
      | pvc-annotation-default  | bound   | StorageClass:\s+gp2-encrypted                                              |
      | pvc-annotation-notexist | pending | "yasun-test-class-not-exist" not found                                     |
      | pvc-annotation-blank    | pending | no persistent volumes available for this claim and no storage class is set |
      | pvc-annotation-alpha    | bound   | StorageClass:\s+gp2-encrypted                                              |
      | pvc-annotation-ebs      | bound   | StorageClass:\s+ebs                                                        |

  # @author yasun@redhat.com
  # @case_id OCP-9792
  Scenario: OCP-9792 Volume emptyDir is limited in the Pod in online openshift
    Given I have a project
    And evaluation of `project.mcs(user: user)` is stored in the :proj_selinux_options clipboard
    And evaluation of `project.supplemental_groups(user: user).begin` is stored in the :supplemental_groups clipboard
    And evaluation of `project.uid_range(user: user).begin` is stored in the :uid_range clipboard

    Given I obtain test data file "storage/emptydir/emptydir_pod_selinux_test.json"
    When I run oc create over "emptydir_pod_selinux_test.json" replacing paths:
      | ["spec"]["containers"][0]["securityContext"]["runAsUser"] | <%= cb.uid_range %>             |
      | ["spec"]["containers"][1]["securityContext"]["runAsUser"] | <%= cb.uid_range %>             |
      | ["spec"]["securityContext"]["fsGroup"]                    | <%= cb.supplemental_groups %>   |
      | ["spec"]["securityContext"]["supplementalGroups"]         | [<%= cb.supplemental_groups %>] |
      | ["spec"]["securityContext"]["seLinuxOptions"]["level"]    | <%= cb.proj_selinux_options %>  |
    Then the step should succeed
    Given the pod named "emptydir" becomes ready
    Then I execute on the pod:
      | bash | -lc | dd if=/dev/zero of=/tmp/openshift-test-1 bs=100M count=6 |
    Then the step should fail
    And the output should contain:
      | Disk quota exceeded |

