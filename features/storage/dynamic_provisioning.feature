Feature: Dynamic provisioning

  # @author lxia@redhat.com
  @admin
  Scenario Outline: dynamic provisioning
    Given I have a project
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc                 |
      | ["metadata"]["name"]                                         | mypod                 |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/<cloud_provider> |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound
    And I save volume id from PV named "<%= pvc.volume_name %>" in the :volumeID clipboard
    When I execute on the pod:
      | touch | /mnt/<cloud_provider>/testfile_1 |
    Then the step should succeed

    Given I ensure "<%= pod.name %>" pod is deleted
    And I ensure "<%= pvc.name %>" pvc is deleted

    Given I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "<%= pvc.volume_name %>" to disappear within 1200 seconds

    Given I use the "<%= pod.node_name %>" node
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
      | azure          | # @case_id OCP-13787


  # @author lxia@redhat.com
  # @case_id OCP-10790
  @admin
  Scenario: Check only one pv created for one pvc for dynamic provisioner
    Given I have a project
    And I run the steps 30 times:
    """
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc#{cb.i} |
    Then the step should succeed
    """
    Given 30 PVCs become :bound within 600 seconds with labels:
      | name=dynamic-pvc |
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
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    When 30 seconds have passed
    Then the "mypvc" PVC status is :pending

    Examples:
      | provisioner |
      | aws-ebs     | # @case_id OCP-10360
      | gce-pd      | # @case_id OCP-10361
      | cinder      | # @case_id OCP-10362
      | azure-disk  | # @case_id OCP-13903

