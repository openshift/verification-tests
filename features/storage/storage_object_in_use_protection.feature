Feature: Storage object in use protection

  # @author lxia@redhat.com
  # @case_id OCP-17253
  @storage
  Scenario: OCP-17253:Storage Delete pvc which is not in active use by pod should be deleted immediately
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    And the expression should be true> pvc("mypvc").finalizers&.include? "kubernetes.io/pvc-protection"
    Given I ensure "mypvc" pvc is deleted

  # @author lxia@redhat.com
  # @case_id OCP-17254
  @storage
  Scenario: OCP-17254:Storage Delete pvc which is in active use by pod should postpone deletion
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
      | ["metadata"]["name"]                                         | mypod |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    And the "mypvc" PVC becomes :bound
    When I run the :delete client command with:
      | object_type       | pvc   |
      | object_name_or_id | mypvc |
      | wait              | false |
    Then the step should succeed
    And the "mypvc" PVC becomes terminating
    When I execute on the pod:
      | touch | /mnt/ocp_pv/testfile |
    Then the step should succeed
    # Comment out due to below bug closed as NOTABUG
    # https://bugzilla.redhat.com/show_bug.cgi?id=1534426
    #When I get project pvc named "mypvc"
    #Then the step should succeed
    #And the output should contain "Terminating"
    When I run the :describe client command with:
      | resource | pvc   |
      | name     | mypvc |
    Then the step should succeed
    And the output should match "Terminating\s+\((since|lasts)"
    Given I ensure "mypod" pod is deleted
    And I wait for the resource "pvc" named "mypvc" to disappear within 30 seconds

  # @author lxia@redhat.com
  # @case_id OCP-18796
  @admin
  @storage
  Scenario: OCP-18796:Storage Delete pv which is bind with pvc should postpone deletion
    Given I have a project
    Given I obtain test data file "storage/nfs/auto/pv-template.json"
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"] | pv-<%= project.name %> |
    Then the step should succeed
    And the PV becomes :available
    And the expression should be true> pv.finalizers&.include? "kubernetes.io/pv-protection"
    Given I obtain test data file "storage/nfs/auto/pvc-template.json"
    When I create a manual pvc from "pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | mypvc                  |
      | ["spec"]["volumeName"] | pv-<%= project.name %> |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV

    When I run the :delete admin command with:
      | object_type       | pv                     |
      | object_name_or_id | pv-<%= project.name %> |
      | wait              | false                  |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV becomes terminating
    When I run the :describe admin command with:
      | resource | pv                     |
      | name     | pv-<%= project.name %> |
    Then the step should succeed
    And the output should match "Terminating\s+\((since|lasts)"
    Given I ensure "mypvc" pvc is deleted
    And I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "pv-<%= project.name %>" to disappear within 30 seconds

