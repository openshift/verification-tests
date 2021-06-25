Feature: CSI Resizing related feature
  # @author chaoyang@redhat.com
  @admin
  Scenario Outline: Resize online volume from 1Gi to 2Gi
    Given I have a project

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"]                 | <sc_name>               |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                     |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod                   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    When I run the :patch client command with:
      | resource      | pvc                                                   |
      | resource_name | pvc-<%= project.name %>                               |
      | p             | {"spec":{"resources":{"requests":{"storage":"2Gi"}}}} |
    Then the step should succeed
    And I wait up to 800 seconds for the steps to pass:
    """
    Given the expression should be true> pv(pvc("pvc-<%= project.name %>").volume_name).capacity_raw(cached: false) == "2Gi"
    And the expression should be true> pvc.capacity(cached: false) == "2Gi"
    """
    When I execute on the pod:
      | /bin/dd | if=/dev/zero | of=/mnt/iaas/1 | bs=1M | count=1500 |
    Then the step should succeed
    And the output should not contain:
      | No space left on device |

    Examples:
      | sc_name      |
      | standard-csi | # @case_id OCP-37479
      | standard-csi | # @case_id OCP-37559
      | gp2-csi      | # @case_id OCP-25808


  # @author wduan@redhat.com
  Scenario Outline: Resize negative test
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"]                 | <sc_name>               |
      | ["spec"]["resources"]["requests"]["storage"] | 2Gi                     |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod                   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    When I run the :patch client command with:
      | resource      | pvc                                                   |
      | resource_name | pvc-<%= project.name %>                               |
      | p             | {"spec":{"resources":{"requests":{"storage":"1Gi"}}}} |
    Then the step should fail
    And the output should match:
      | Forbidden.*field can not be less than previous value |

    Examples:
      | sc_name |
      | gp2-csi | # @case_id OCP-25809
