Feature: Dynamic provisioning

  # @author lxia@redhat.com
  @admin
  Scenario Outline: dynamic provisioning
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
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
