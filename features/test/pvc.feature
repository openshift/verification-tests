Feature: pvc testing scenarios

  Scenario: fetch pvc detail when got wrong status
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"] | nfsc-<%= project.name %> |
    Then the step should succeed
    And the "nfsc-<%= project.name %>" PVC becomes :bound

  Scenario: check pvc.storage_class
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]                                                   | pvc-<%= project.name %> |
      | ["metadata"]["annotations"]["volume.beta.kubernetes.io/storage-class"] | sc-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :pending
    And the expression should be true> pvc.storage_class(user: user) == "sc-<%= project.name %>"
