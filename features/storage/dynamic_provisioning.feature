Feature: Dynamic provisioning

  # @author lxia@redhat.com
  @admin
  Scenario Outline: dynamic provisioning
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I run the :oadm_new_project admin command with:
      | project_name  | <%= cb.proj_name %>         |
      | node_selector | <%= cb.proj_name %>=dynamic |
      | admin         | <%= user.name %>            |
    Then the step should succeed

    Given I store the ready and schedulable nodes in the :nodes clipboard
    And label "<%= cb.proj_name %>=dynamic" is added to the "<%= cb.nodes[0].name %>" node

    Given I switch to cluster admin pseudo user
    And I use the "<%= cb.proj_name %>" project

    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | dynamic-pvc1-<%= project.name %> |
    Then the step should succeed
    And the "dynamic-pvc1-<%= project.name %>" PVC becomes :bound

    And I save volume id from PV named "<%= pvc.volume_name %>" in the :volumeID clipboard

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | <%= pvc.name %>       |
      | ["metadata"]["name"]                                         | mypod1                |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/<cloud_provider> |
    Then the step should succeed
    And the pod named "mypod1" becomes ready
    When I execute on the pod:
      | touch | /mnt/<cloud_provider>/testfile_1 |
    Then the step should succeed

    Given I ensure "<%= pod.name %>" pod is deleted
    And I ensure "<%= pvc.name %>" pvc is deleted

    Given I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 1200 seconds

    Given I use the "<%= cb.nodes[0].name %>" node
    When I run commands on the host:
      | mount |
    Then the step should succeed
    And the output should not contain:
      | <%= pvc.volume_name %> |
      | <%= cb.volumeID %>     |
    And I verify that the IAAS volume with id "<%= cb.volumeID %>" was deleted

    Examples:
      | cloud_provider |
      | cinder         | # @case_id OCP-9656
      | ebs            | # @case_id OCP-9685
      | gce            | # @case_id OCP-12665

  # @author wehe@redhat.com
  # @case_id OCP-13787
  @admin
  Scenario: azure disk dynamic provisioning
    Given admin creates a project with a random schedulable node selector
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/azure/azsc-NOPAR.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
    Then the step should succeed
    Given evaluation of `%w{ReadWriteOnce ReadWriteOnce ReadWriteOnce}` is stored in the :accessmodes clipboard
    And I run the steps 1 times:
    """
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/azure/azpvc-sc.yaml" replacing paths:
      | ["metadata"]["name"]                                                   | dpvc-#{cb.i}              |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>    |
      | ["spec"]["accessModes"][0]                                             | #{cb.accessmodes[cb.i-1]} |
      | ["spec"]["resources"]["requests"]["storage"]                           | #{cb.i}Gi                 |
    Then the step should succeed
    And the "dpvc-#{cb.i}" PVC becomes :bound within 120 seconds
    And I save volume id from PV named "#{ pvc.volume_name }" in the :disk clipboard
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/azure/azpvcpod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | dpvc-#{cb.i} |
      | ["metadata"]["name"]                                         | mypod#{cb.i} |
    Then the step should succeed
    And the pod named "mypod#{cb.i}" becomes ready
    When I execute on the pod:
      | touch | /mnt/azure/testfile_#{cb.i} |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | pod |
      | all         |     |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | pvc |
      | all         |     |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "#{ pvc.volume_name }" to disappear within 1200 seconds
    Given I use the "<%= node.name %>" node
    And I run commands on the host:
      | mount |
    And the output should not contain:
      | #{ pvc.volume_name }       |
      | #{cb.disk.split("/").last} |
    """

  # @author lxia@redhat.com
  # @case_id OCP-10790
  @admin
  Scenario: Check only one pv created for one pvc for dynamic provisioner
    Given I have a project
    And I run the steps 30 times:
    """
    When I run oc create over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc-ERB.json
    Then the step should succeed
    """
    Given 30 PVCs become :bound within 600 seconds with labels:
      | name=dynamic-pvc-<%= project.name %> |
    When I run the :get admin command with:
      | resource | pv |
    Then the output should contain 30 times:
      | <%= project.name %> |

  # @author jhou@redhat.com
  @admin
  @destructive
  Scenario Outline: No volume and PV provisioned when provisioner is disabled
    Given I have a project
    And master config is merged with the following hash:
    """
    volumeConfig:
      dynamicProvisioningEnabled: False
    """
    And the master service is restarted on all master nodes
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | dynamic-pvc-<%= project.name %> |
    Then the step should succeed
    When 30 seconds have passed
    Then the "dynamic-pvc-<%= project.name %>" PVC status is :pending

    Examples:
      | provisioner |
      | aws-ebs     | # @case_id OCP-10360
      | gce-pd      | # @case_id OCP-10361
      | cinder      | # @case_id OCP-10362
      | azure-disk  | # @case_id OCP-13903

