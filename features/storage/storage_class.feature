Feature: storageClass related feature

  # @author lxia@redhat.com
  @admin
  @destructive
  Scenario Outline: PVC modification after creating storage class
    Given I have a project
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :pending
    Given 30 seconds have passed
    And the "pvc-<%= project.name %>" PVC status is :pending

    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/storageClass.yaml" where:
      | ["metadata"]["name"]                                                            | sc-<%= project.name %>      |
      | ["provisioner"]                                                                 | kubernetes.io/<provisioner> |
      | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | true                        |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | pvc                                                    |
      | resource_name | pvc-<%= project.name %>                                |
      | p             | {"metadata":{"labels":{"<%= project.name %>":"test"}}} |
    Then the step should succeed
    Given 30 seconds have passed
    And the "pvc-<%= project.name %>" PVC status is :pending
    When I run the :patch client command with:
      | resource      | pvc                                                                                               |
      | resource_name | pvc-<%= project.name %>                                                                           |
      | p             | {"metadata":{"annotations":{"volume.beta.kubernetes.io/storage-class":"sc-<%= project.name %>"}}} |
    Then the expression should be true> @result[:success] == env.version_le("3.5", user: user)

    Examples:
      | provisioner |
      | gce-pd      | # @case_id OCP-12089
      | aws-ebs     | # @case_id OCP-12269
      | cinder      | # @case_id OCP-12272
      | azure-disk  | # @case_id OCP-13488

  # @author lxia@redhat.com
  @admin
  @destructive
  Scenario Outline: No dynamic provision when no default storage class
    Given I have a project
    And default storage class is deleted
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/storageClass.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %>      |
      | ["provisioner"]      | kubernetes.io/<provisioner> |
    Then the step should succeed
    # "oc get storageclass -o yaml"
    # should contain string 'kind: StorageClass' when there are storageclass
    # should not contain string 'is-default-class: "true"' when there are no default storageclass
    When I run the :get admin command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    And the output should contain "kind: StorageClass"
    And the output should not contain:
      | is-default-class: "true" |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :pending
    Given 30 seconds have passed
    And the "pvc-<%= project.name %>" PVC status is :pending

    Examples:
      | provisioner |
      | gce-pd      | # @case_id OCP-12090
      | aws-ebs     | # @case_id OCP-12096
      | cinder      | # @case_id OCP-12097
      | azure-disk  | # @case_id OCP-13489

  # @author lxia@redhat.com
  # @author chaoyang@redhat.com
  @admin
  @destructive
  Scenario Outline: storage class provisioner
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/gce/storageClass.yaml" where:
      | ["metadata"]["name"]                                                            | sc-<%= project.name %>      |
      | ["provisioner"]                                                                 | kubernetes.io/<provisioner> |
      | ["parameters"]["type"]                                                          | <type>                      |
      | ["parameters"]["zone"]                                                          | <zone>                      |
      | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | <is-default>                |
    Then the step should succeed

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["spec"]["accessModes"][0]                                             | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"]                           | <size>                  |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds
    And the expression should be true> pvc.capacity == "<size>"
    And the expression should be true> pvc.access_modes[0] == "ReadWriteOnce"
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Delete"
    # ToDo
    # check storage size info
    # check storage type info
    # check storage zone info
    # gcloud compute disks describe --zone <zone> diskNameViaPvInfo

    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | pod-<%= project.name %> |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "pod-<%= project.name %>" becomes ready
    When I execute on the pod:
      | ls | -ld | /mnt/iaas/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/iaas/testfile |
    Then the step should succeed
    Given I ensure "pod-<%= project.name %>" pod is deleted
    Given I ensure "pvc-<%= project.name %>" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear

    Examples:
      | provisioner | type        | zone          | is-default | size  |
      | gce-pd      | pd-ssd      | us-central1-a | false      | 1Gi   | # @case_id OCP-11359
      | gce-pd      | pd-standard | us-central1-a | false      | 2Gi   | # @case_id OCP-11640
      | aws-ebs     | gp2         | us-east-1d    | false      | 1Gi   | # @case_id OCP-10160
      | aws-ebs     | sc1         | us-east-1d    | false      | 500Gi | # @case_id OCP-10161
      | aws-ebs     | st1         | us-east-1d    | false      | 500Gi | # @case_id OCP-10424

  # @author lxia@redhat.com
  @admin
  @destructive
  Scenario Outline: New creation PVC failed when multiple classes are set as default
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/storageClass.yaml" where:
      | ["metadata"]["name"]                                                            | sc1-<%= project.name %>     |
      | ["provisioner"]                                                                 | kubernetes.io/<provisioner> |
      | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | true                        |
    Then the step should succeed
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/storageClass.yaml" where:
      | ["metadata"]["name"]                                                            | sc2-<%= project.name %>     |
      | ["provisioner"]                                                                 | kubernetes.io/<provisioner> |
      | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | true                        |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | should-fail-<%= project.name %> |
    Then the step should fail
    And the output should match:
      | Internal error occurred |
      | ([2-9]\|[1-9][0-9]+) default StorageClasses were found |
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc1-<%= project.name %>  |
    Then the step should succeed
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc2-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc2-<%= project.name %>  |
    Then the step should succeed
    And the "pvc1-<%= project.name %>" PVC becomes :bound within 120 seconds
    And the "pvc2-<%= project.name %>" PVC becomes :bound within 120 seconds

    Examples:
      | provisioner |
      | gce-pd      | # @case_id OCP-12223
      | aws-ebs     | # @case_id OCP-12226
      | cinder      | # @case_id OCP-12227
      | azure-disk  | # @case_id OCP-13490

  # @author lxia@redhat.com
  Scenario Outline: New created PVC without specifying storage class use default class when only one class is marked as default
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc-without-annotations.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    And the expression should be true> pvc("mypvc").storage_class == "<default-storage-class-name>"

    Examples:
      | provisioner | default-storage-class-name |
      | gce-pd      | standard                   | # @case_id OCP-12171
      | aws-ebs     | gp2                        | # @case_id OCP-12176
      | cinder      | standard                   | # @case_id OCP-12177
      | azure-disk  | managed-premium            | # @case_id OCP-13492

  # @author chaoyang@redhat.com
  @admin
  Scenario Outline: PVC with storage class will provision pv with io1 type and 100/20000 iops ebs volume
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/dynamic-provisioning/storageclass-io1.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
    Then the step should succeed

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["spec"]["accessModes"][0]                                             | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"]                           | <size>                  |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds
    And the expression should be true> pvc.capacity == "<size>"
    And the expression should be true> pvc.access_modes[0] == "ReadWriteOnce"
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Delete"

    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | pod-<%= project.name %> |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "pod-<%= project.name %>" becomes ready
    When I execute on the pod:
      | ls | -ld | /mnt/iaas/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/iaas/testfile |
    Then the step should succeed
    Given I ensure "pod-<%= project.name %>" pod is deleted
    Given I ensure "pvc-<%= project.name %>" pvc is deleted
    Given I switch to cluster admin pseudo user
    And I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 300 seconds

    Examples:
      | size  |
      | 4Gi   | # @case_id OCP-10158
      | 800Gi | # @case_id OCP-10162

  # @author chaoyang@redhat.com
  @admin
  Scenario Outline: PVC with storage class will not provision pv with st1/sc1 type ebs volume if request size is wrong
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/dynamic-provisioning/storageclass.yaml" where:
      | ["metadata"]["name"]   | sc-<%= project.name %> |
      | ["provisioner"]        | kubernetes.io/aws-ebs  |
      | ["parameters"]["type"] | <type>                 |
      | ["parameters"]["zone"] | us-east-1d             |
    Then the step should succeed

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["spec"]["accessModes"][0]                                             | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"]                           | <size>                  |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>  |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/pvc-<%= project.name %> |
    Then the output should contain:
      | ProvisioningFailed    |
      | InvalidParameterValue |
      | <errorMessage>        |
    """

    Examples:
      | type | size | errorMessage                  |
      | sc1  | 5Gi  | at least 500 GiB              | # @case_id OCP-10164
      | st1  | 17Ti | too large for volume type st1 | # @case_id OCP-10425

  # @author chaoyang@redhat.com
  # @case_id OCP-10159
  @admin
  Scenario: PVC with storage class won't provisioned pv if no storage class or wrong storage class object
    Given I have a project
    # No sc exists
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc1-<%= project.name %> |
      | ["spec"]["accessModes"][0]                                             | ReadWriteOnce            |
      | ["spec"]["resources"]["requests"]["storage"]                           | 1Gi                      |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc1-<%= project.name %>  |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pvc/pvc1-<%= project.name %> |
    And the output should contain:
      | ProvisioningFailed                  |
      | "sc1-<%= project.name %>" not found |
    """

  # @author chaoyang@redhat.com
  # @case_id OCP-10228
  Scenario: AWS ebs volume is dynamic provisioned with default storageclass
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/ebs/pvc-retain.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-<%= project.name %> |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                     |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound

