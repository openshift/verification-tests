Feature: storageClass related feature

  # @author lxia@redhat.com
  @admin
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PVC modification after creating storage class
    Given I have a project
    Given I obtain test data file "storage/misc/pvc-without-annotations.json"
    When I create a manual pvc from "pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    And the "mypvc" PVC becomes :pending
    Given 30 seconds have passed
    And the "mypvc" PVC status is :pending

    When I run the :patch client command with:
      | resource      | pvc                                                    |
      | resource_name | mypvc                                                  |
      | p             | {"metadata":{"labels":{"<%= project.name %>":"test"}}} |
    Then the step should succeed
    Given 30 seconds have passed
    And the "mypvc" PVC status is :pending
    When I run the :patch client command with:
      | resource      | pvc                                                                                             |
      | resource_name | mypvc                                                                                           |
      | p             | {"metadata":{"annotations":{"volume.beta.kubernetes.io/storage-class":"<storage-class-name>"}}} |
    Then the expression should be true> @result[:success] == env.version_le("3.5", user: user)

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    Examples:
      | case_id           | storage-class-name |
      | OCP-12269:Storage | gp2                | # @case_id OCP-12269

    @rosa @osd_ccs @aro
    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | storage-class-name |
      | OCP-12089:Storage | standard           | # @case_id OCP-12089

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id           | storage-class-name |
      | OCP-12272:Storage | standard           | # @case_id OCP-12272

    @rosa @osd_ccs @aro
    @azure-ipi
    @azure-upi
    @hypershift-hosted
    Examples:
      | case_id           | storage-class-name |
      | OCP-13488:Storage | managed-premium    | # @case_id OCP-13488

  # @author lxia@redhat.com
  # @author chaoyang@redhat.com
  @admin
  @smoke
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: storage class provisioner
    Given I have a project
    And admin clones storage class "sc-<%= project.name %>" from ":default" with:
      | ["parameters"]["type"] | <type> |

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc                   |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"] | <size>                  |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %>  |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod     |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc     |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound within 120 seconds
    And the expression should be true> pvc.capacity == "<size>"
    And the expression should be true> pvc.access_modes[0] == "ReadWriteOnce"
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Delete"
    When I execute on the pod:
      | ls | -ld | /mnt/iaas/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/iaas/testfile |
    Then the step should succeed
    Given I ensure "mypod" pod is deleted
    Given I ensure "mypvc" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear

    @rosa @osd_ccs @aro
    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | provisioner | type        | zone          | is-default | size |
      | OCP-11359:Storage | gce-pd      | pd-ssd      | us-central1-a | false      | 1Gi  | # @case_id OCP-11359
      | OCP-11640:Storage | gce-pd      | pd-standard | us-central1-a | false      | 2Gi  | # @case_id OCP-11640

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id           | provisioner | type | zone       | is-default | size  |
      | OCP-10160:Storage | aws-ebs     | gp2  | us-east-1d | false      | 1Gi   | # @case_id OCP-10160
      | OCP-10161:Storage | aws-ebs     | sc1  | us-east-1d | false      | 500Gi | # @case_id OCP-10161
      | OCP-10424:Storage | aws-ebs     | st1  | us-east-1d | false      | 500Gi | # @case_id OCP-10424

  # @author lxia@redhat.com
  @admin
  @destructive
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: New creation PVC failed when multiple classes are set as default
    Given I have a project
    Given I obtain test data file "storage/misc/storageClass.yaml"
    When admin creates a StorageClass from "storageClass.yaml" where:
      | ["metadata"]["name"]                                                       | sc1-<%= project.name %>     |
      | ["provisioner"]                                                            | kubernetes.io/<provisioner> |
      | ["metadata"]["annotations"]["storageclass.kubernetes.io/is-default-class"] | true                        |
    Then the step should succeed
    Given I obtain test data file "storage/misc/storageClass.yaml"
    When admin creates a StorageClass from "storageClass.yaml" where:
      | ["metadata"]["name"]                                                       | sc2-<%= project.name %>     |
      | ["provisioner"]                                                            | kubernetes.io/<provisioner> |
      | ["metadata"]["annotations"]["storageclass.kubernetes.io/is-default-class"] | true                        |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc-without-annotations.json"
    When I run oc create over "pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | should-fail |
    Then the step should fail
    And the output should match:
      | Internal error occurred |
      | ([2-9]\|[1-9][0-9]+) default StorageClasses were found |
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc1 |
      | ["spec"]["storageClassName"] | sc1-<%= project.name %>  |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc2 |
      | ["spec"]["storageClassName"] | sc2-<%= project.name %>  |
    Then the step should succeed
    And the "mypvc1" PVC becomes :bound within 120 seconds
    And the "mypvc2" PVC becomes :bound within 120 seconds

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    Examples:
      | case_id           | provisioner |
      | OCP-12226:Storage | aws-ebs     | # @case_id OCP-12226

    @rosa @osd_ccs @aro
    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | provisioner |
      | OCP-13490:Storage | azure-disk  | # @case_id OCP-13490

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id           | provisioner |
      | OCP-12227:Storage | cinder      | # @case_id OCP-12227

    @rosa @osd_ccs @aro
    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | provisioner |
      | OCP-12223:Storage | gce-pd      | # @case_id OCP-12223

    @vsphere-ipi
    @vsphere-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id           | provisioner    |
      | OCP-24259:Storage | vsphere-volume | # @case_id OCP-24259

  # @author lxia@redhat.com
  @inactive
  @storage
  Scenario Outline: New created PVC without specifying storage class use default class when only one class is marked as default
    Given I have a project
    Given I obtain test data file "storage/misc/pvc-without-annotations.json"
    When I run oc create over "pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    And the expression should be true> pvc("mypvc").storage_class == "<default-storage-class-name>"

    Examples:
      | case_id           | provisioner    | default-storage-class-name |
      | OCP-12176:Storage | aws-ebs        | gp2                        | # @case_id OCP-12176
      | OCP-13492:Storage | azure-disk     | managed-premium            | # @case_id OCP-13492
      | OCP-12177:Storage | cinder         | standard                   | # @case_id OCP-12177
      | OCP-12171:Storage | gce-pd         | standard                   | # @case_id OCP-12171
      | OCP-25789:Storage | vsphere-volume | thin                       | # @case_id OCP-25789

  # @author chaoyang@redhat.com
  @admin
  @singlenode
  @proxy @noproxy @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PVC with storage class will provision pv with io1 type and 100/20000 iops ebs volume
    Given I have a project
    Given I obtain test data file "storage/ebs/dynamic-provisioning/storageclass-io1.yaml"
    When admin creates a StorageClass from "storageclass-io1.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"] | <size>                  |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %>  |
    Then the step should succeed
    And the "mypvc" PVC becomes :bound within 120 seconds
    And the expression should be true> pvc.capacity == "<size>"
    And the expression should be true> pvc.access_modes[0] == "ReadWriteOnce"
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Delete"

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    When I execute on the pod:
      | ls | -ld | /mnt/iaas/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/iaas/testfile |
    Then the step should succeed
    Given I ensure "mypod" pod is deleted
    Given I ensure "mypvc" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    @hypershift-hosted
    Examples:
      | case_id           | size  |
      | OCP-10158:Storage | 4Gi   | # @case_id OCP-10158
      | OCP-10162:Storage | 800Gi | # @case_id OCP-10162

  # @author chaoyang@redhat.com
  @admin
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: PVC with storage class will not provision pv with st1/sc1 type ebs volume if request size is wrong
    Given I have a project
    Given I obtain test data file "storage/ebs/dynamic-provisioning/storageclass.yaml"
    When admin creates a StorageClass from "storageclass.yaml" where:
      | ["metadata"]["name"]   | sc-<%= project.name %> |
      | ["provisioner"]        | kubernetes.io/aws-ebs  |
      | ["parameters"]["type"] | <type>                 |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"] | <size>                  |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %>  |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/mypvc |
    Then the output should contain:
      | ProvisioningFailed    |
      | InvalidParameterValue |
      | <errorMessage>        |
    """

    @rosa @osd_ccs @aro
    @aws-ipi
    @aws-upi
    @hypershift-hosted
    Examples:
      | case_id           | type | size | errorMessage                  |
      | OCP-10164:Storage | sc1  | 5Gi  | at least 125 GiB              | # @case_id OCP-10164
      | OCP-10425:Storage | st1  | 17Ti | too large for volume type st1 | # @case_id OCP-10425

  # @author chaoyang@redhat.com
  # @case_id OCP-10159
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @rosa @osd_ccs @aro
  @aws-ipi
  @aws-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @storage
  Scenario: OCP-10159:Storage PVC with storage class won't provisioned pv if no storage class or wrong storage class object
    Given I have a project
    # No sc exists
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce            |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                      |
      | ["spec"]["storageClassName"]                 | sc1-<%= project.name %>  |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/mypvc |
    And the output should contain:
      | ProvisioningFailed                  |
      | "sc1-<%= project.name %>" not found |
    """

  # @author chaoyang@redhat.com
  # @case_id OCP-10228
  @smoke
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @rosa @osd_ccs @aro
  @aws-ipi
  @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  @storage
  Scenario: OCP-10228:Storage AWS ebs volume is dynamic provisioned with default storageclass
    Given I have a project
    Given I obtain test data file "storage/ebs/pvc-retain.json"
    When I run oc create over "pvc-retain.json" replacing paths:
      | ["metadata"]["name"]                         | mypvc |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                     |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    And the pod named "mypod" becomes ready
