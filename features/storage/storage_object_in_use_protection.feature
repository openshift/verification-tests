Feature: Storage object in use protection

  # @author lxia@redhat.com
  # @case_id OCP-17253
  Scenario: OCP-17253 Delete pvc which is not in active use by pod should be deleted immediately
    Given I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound
    And the expression should be true> pvc.finalizers&.include? "kubernetes.io/pvc-protection"
    Given I ensure "pvc-<%= project.name %>" pvc is deleted

  # @author lxia@redhat.com
  # @case_id OCP-17254
  Scenario: OCP-17254 Delete pvc which is in active use by pod should postpone deletion
    Given I have a project
    When I create a dynamic pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound
    When I run oc create over "https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/misc/pod.yaml" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["metadata"]["name"]                                         | mypod                   |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    When I run the :delete client command with:
      | object_type       | pvc                     |
      | object_name_or_id | pvc-<%= project.name %> |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes terminating
    When I execute on the pod:
      | touch | /mnt/ocp_pv/testfile |
    Then the step should succeed
    # Comment out due to below bug closed as NOTABUG
    # https://bugzilla.redhat.com/show_bug.cgi?id=1534426
    #When I get project pvc named "pvc-<%= project.name %>"
    #Then the step should succeed
    #And the output should contain "Terminating"
    When I run the :describe client command with:
      | resource | pvc                     |
      | name     | pvc-<%= project.name %> |
    Then the step should succeed
    And the output should match "Terminating\s+\((since|lasts)"
    Given I ensure "mypod" pod is deleted
    And I wait for the resource "pvc" named "pvc-<%= project.name %>" to disappear within 30 seconds

  # @author lxia@redhat.com
  # @case_id OCP-18796
  @admin
  Scenario: OCP-18796 Delete pv which is bind with pvc should postpone deletion
    Given I have a project
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pv-template.json" where:
      | ["metadata"]["name"] | pv-<%= project.name %> |
    Then the step should succeed
    And the PV becomes :available
    And the expression should be true> pv.finalizers&.include? "kubernetes.io/pv-protection"
    When I create a manual pvc from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | pvc-<%= project.name %> |
      | ["spec"]["volumeName"] | pv-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes bound to the "pv-<%= project.name %>" PV

    When I run the :delete admin command with:
      | object_type       | pv                     |
      | object_name_or_id | pv-<%= project.name %> |
    Then the step should succeed
    And the "pv-<%= project.name %>" PV becomes terminating
    When I run the :describe admin command with:
      | resource | pv                     |
      | name     | pv-<%= project.name %> |
    Then the step should succeed
    And the output should match "Terminating\s+\((since|lasts)"
    Given I ensure "pvc-<%= project.name %>" pvc is deleted
    And I switch to cluster admin pseudo user
    Then I wait for the resource "pv" named "pv-<%= project.name %>" to disappear within 30 seconds

