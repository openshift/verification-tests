Feature: CSI testing related feature

  # @author chaoyang@redhat.com
  # @case_id OCP-30787
  @admin
  @stage-only
  Scenario: CSI images checking in stage and prod env
    Given the master version >= "4.4"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"
    When I run the :get admin command with:
      | resource | volumesnapshot |
    Then the output should contain "true"

  # @author chaoyang@redhat.com
  # @case_id OCP-31345
  @admin
  @stage-only
  Scenario: CSI images checking in stage env in OCP4.3
    Given the master version == "4.3"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"

  # @author chaoyang@redhat.com
  # @case_id OCP-31346
  @admin
  @stage-only
  Scenario: CSI images checking in stage env in OCP4.2
    Given the master version == "4.2"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running

  # @author chaoyang@redhat.com
  @admin
  @4.10 @4.9
  Scenario Outline: Configure 'Retain' reclaim policy
    Given I have a project
    And admin clones storage class "sc-<%= project.name %>" from "<sc_name>" with:
      | ["metadata"]["name"] | sc-<%= project.name %>      |
      | ["reclaimPolicy"]    | Retain                      |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %>  |
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
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Retain"

    And I ensure "mypod" pod is deleted
    When I ensure "pvc-<%= project.name %>" pvc is deleted
    Then the PV becomes :released
    And admin ensures "<%= pvc.volume_name %>" pv is deleted

    @openstack-ipi @aws-ipi
    @openstack-upi @aws-upi
    Examples:
      | sc_name      |
      | gp2-csi      | # @case_id OCP-24575

    Examples:
      | sc_name      |
      | standard-csi | # @case_id OCP-37572


  # @author wduan@redhat.com
  @admin
  @smoke
  @4.10 @4.9
  Scenario Outline: CSI dynamic provisioning with default fstype
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc     |
      | ["spec"]["storageClassName"] | <sc_name> |
    Then the step should succeed
    Given I obtain test data file "storage/misc/deployment.yaml"
    When I run oc create over "deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep      |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | storage    |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc      |
      | ["spec"]["template"]["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    And the "mypvc" PVC becomes :bound
    When I execute on the pod:
      | sh | -c | echo "test" > /mnt/local/testfile |
    Then the step should succeed
    When I execute on the pod:
      | cp | /hello | /mnt/local |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/local/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"

    Given I use the "<%= pod.node_name %>" node
    When I run commands on the host:
      | mount |
    Then the output should contain:
      | <%= pvc.volume_name %> |

    When I run the :scale admin command with:
      | resource | deployment          |
      | name     | mydep               |
      | replicas | 0                   |
      | n        | <%= project.name %> |
    Then the step should succeed
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear
    And I wait up to 30 seconds for the steps to pass:
    """
    Given I use the "<%= pod.node_name %>" node
    When I run commands on the host:
      | mount |
    Then the output should not contain:
      | <%= pvc.volume_name %> |
    """

    When I run the :scale client command with:
      | resource | deployment          |
      | name     | mydep               |
      | replicas | 1                   |
      | n        | <%= project.name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    When I execute on the pod:
      | ls | -l | /mnt/local |
    Then the step should succeed
    And the output should contain:
      | testfile |
      | hello    |
    When I execute on the pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "test"

    @openstack-ipi
    @openstack-upi
    Examples:
      | sc_name      |
      | standard-csi | # @case_id OCP-37562


  # @author wduan@redhat.com
  @admin
  @smoke
  @4.10 @4.9
  Scenario Outline: CSI dynamic provisioning with fstype
    Given I have a project
    When admin clones storage class "sc-<%= project.name %>" from "<sc_name>" with:
      | ["parameters"]["csi.storage.k8s.io/fstype"] | <fstype> |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod      |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc      |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound

    When I execute on the pod:
      | mount |
    Then the step should succeed
    And the output should contain:
      | /mnt/local type <fstype> |
    When I execute on the pod:
      | touch | /mnt/local/testfile |
    Then the step should succeed
    When I execute on the pod:
      | ls | /mnt/local/testfile |
    Then the step should succeed
    When I execute on the pod:
      | cp | /hello | /mnt/local |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/local/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"

    @openstack-ipi
    @openstack-upi
    Examples:
      | sc_name       | fstype |
      | standard-csi  | xfs    | # @case_id OCP-37560
      | standard-csi  | ext4   | # @case_id OCP-37558


  # @author wduan@redhat.com
  @4.10 @4.9
  Scenario Outline: CSI dynamic provisioning with block
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc     |
      | ["spec"]["storageClassName"] | <sc_name> |
      | ["spec"]["volumeMode"]       | Block     |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod-with-block-volume.yaml"
    When I run oc create over "pod-with-block-volume.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod       |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc       |
      | ["spec"]["containers"][0]["volumeDevices"][0]["devicePath"]  | /dev/dblock |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound
    When I execute on the pod:
      | sh | -c | [[ -b /dev/dblock ]] |
    Then the step should succeed
    When I execute on the pod:
      | /bin/dd | if=/dev/zero | of=/dev/dblock | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | echo "test data" > /dev/dblock |
    Then the step should succeed
    When I execute on the pod:
      | /bin/dd | if=/dev/dblock | of=/tmp/testfile | bs=1M | count=1 |
    Then the step should succeed
    When I execute on the pod:
      | sh | -c | cat /tmp/testfile |
    Then the step should succeed
    And the output should contain "test data"

    @openstack-ipi
    @openstack-upi
    Examples:
      | sc_name      |
      | standard-csi | # @case_id OCP-37564

    Examples:
      | sc_name      |
      | standard-csi | # @case_id OCP-37511


  # @author wduan@redhat.com
  @admin
  @4.10 @4.9
  Scenario Outline: CSI dynamic provisioning with different type
    Given I have a project
    And admin clones storage class "sc-<%= project.name %>" from "<sc_name>" with:
      | ["parameters"]["type"] | <type> |

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc                  |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | <size>                 |
    Then the step should succeed

    Given I obtain test data file "storage/misc/deployment.yaml"
    When I run oc create over "deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep      |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | storage    |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc      |
      | ["spec"]["template"]["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=storage |
    And the "mypvc" PVC becomes :bound
    And the expression should be true> pvc.capacity == "<size>"
    When I execute on the pod:
      | sh | -c | echo "test" > /mnt/local/testfile |
    Then the step should succeed
    When I execute on the pod:
      | cp | /hello | /mnt/local |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/local/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"

    @aws-ipi
    @aws-upi
    Examples:
      | sc_name      | type   | size  |
      | gp2-csi      | sc1    | 125Gi | # @case_id OCP-24546
      | gp2-csi      | st1    | 125Gi | # @case_id OCP-24572

    Examples:
      | sc_name      | type   | size  |
      | standard-csi | pd-ssd | 1Gi   | # @case_id OCP-37478


  # @author wduan@redhat.com
  @admin
  @4.10 @4.9
  Scenario Outline: Check CSI Driver Operator installation
    When I run the :get admin command with:
      | resource | clusteroperator/storage                                                            |
      | o        | custom-columns=csi:.status.relatedObjects[?(@.resource=="clustercsidrivers")].name |
    Then the step should succeed
    And the output should contain:
      | <provisioner> |
    When I run the :get admin command with:
      | resource | clustercsidrivers |
    Then the step should succeed
    And the output should contain:
      | <provisioner> |
    When I run the :get admin command with:
      | resource  | deployment/<deployment_operator>                             |
      | o         | custom-columns=Management:.metadata.managedFields[*].manager |
      | namespace | openshift-cluster-csi-drivers                                |
    Then the step should succeed
    And the output should contain:
      | cluster-storage-operator |
      | kube-controller-manager  |
    When I run the :get client command with:
      | resource | storageclass |
    Then the output should match:
      | <sc_name>.*<provisioner>|

    When I switch to cluster admin pseudo user
    Given "<deployment_operator>" deployment becomes ready in the "openshift-cluster-csi-drivers" project
    Given "<deployment_controller>" deployment becomes ready in the "openshift-cluster-csi-drivers" project
    Given "<daemonset_node>" daemonset becomes ready in the "openshift-cluster-csi-drivers" project

    @openstack-ipi @aws-ipi
    @openstack-upi @aws-upi
    Examples:
      | provisioner              | sc_name      | deployment_operator                  | deployment_controller                  | daemonset_node                   |
      | cinder.csi.openstack.org | standard-csi | openstack-cinder-csi-driver-operator | openstack-cinder-csi-driver-controller | openstack-cinder-csi-driver-node | # @case_id OCP-37557

    Examples:
      | provisioner              | sc_name      | deployment_operator                  | deployment_controller                  | daemonset_node                   |
      | ebs.csi.aws.com          | gp2-csi      | aws-ebs-csi-driver-operator          | aws-ebs-csi-driver-controller          | aws-ebs-csi-driver-node          | # @case_id OCP-34144

    Examples:
      | provisioner              | sc_name      | deployment_operator                  | deployment_controller                  | daemonset_node                   |
      | pd.csi.storage.gke.io    | standard-csi | gcp-pd-csi-driver-operator           | gcp-pd-csi-driver-controller           | gcp-pd-csi-driver-node           | # @case_id OCP-37474
