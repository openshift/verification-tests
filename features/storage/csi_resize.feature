Feature: CSI Resizing related feature

  # @author chaoyang@redhat.com
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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

    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | sc_name      |
      | OCP-37479:Storage | standard-csi | # @case_id OCP-37479

    @aws-ipi
    @aws-upi
    Examples:
      | case_id           | sc_name |
      | OCP-25808:Storage | gp2-csi | # @case_id OCP-25808

    @openstack-ipi
    @openstack-upi
    @upgrade-sanity
    @singlenode
    @proxy @noproxy @disconnected @connected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    Examples:
      | case_id           | sc_name      |
      | OCP-37559:Storage | standard-csi | # @case_id OCP-37559

  # @author wduan@redhat.com
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
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

    @singlenode
    @proxy @noproxy @disconnected @connected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    Examples:
      | case_id           | sc_name |
      | OCP-25809:Storage | gp2-csi | # @case_id OCP-25809

  # @author ropatil@redhat.com
  @admin
  Scenario Outline: CSI Resize offline volume expansion from 1Gi to 2Gi
    Given I have a project

    # Create pvc with csi storage class
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc     |
      | ["spec"]["storageClassName"]                 | <sc_name> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi       |
    Then the step should succeed

    # Create deployment with pvc and check for pvc bound status
    Given I obtain test data file "storage/misc/deployment.yaml"
    When I run oc create over "deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep        |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | storage      |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc        |
      | ["spec"]["template"]["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/storage |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    And the "mypvc" PVC becomes :bound

    # Apply the patch command to resize the pvc storage size
    When I run the :patch client command with:
      | resource      | pvc                                                   |
      | resource_name | mypvc                                                 |
      | p             | {"spec":{"resources":{"requests":{"storage":"2Gi"}}}} |
    Then the step should succeed
    And the output should match:
      | persistentvolumeclaim/mypvc patched |

    # Scale the deployment and wait till it gets disappeared
    When I run the :scale admin command with:
      | resource | deployment          |
      | name     | mydep               |
      | replicas | 0                   |
      | n        | <%= project.name %> |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear

    #Check the pvc status whether its ready to enable pvc resize
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc   |
      | name     | mypvc |
    Then the step should succeed
    And the output should contain:
      | FileSystemResizePending |
    """

    # Scale the deployment and check for ready status
    When I run the :scale client command with:
      | resource | deployment          |
      | name     | mydep               |
      | replicas | 1                   |
      | n        | <%= project.name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |

    # Check the pv,pvc capacity size
    And I wait up to 180 seconds for the steps to pass:
    """
    Given the expression should be true> pv(pvc("mypvc").volume_name).capacity_raw(cached: false) == "2Gi"
    And the expression should be true> pvc.capacity(cached: false) == "2Gi"
    """

    # Write data
    When I execute on the pod:
      | /bin/dd | if=/dev/zero | of=/mnt/storage/1 | bs=1M | count=1500 |
    Then the step should succeed
    And the output should not contain:
      | No space left on device |

    Examples:
      | case_id            | sc_name     |
      | OCP-41452::Storage | managed-csi | # @case_id OCP-41452
