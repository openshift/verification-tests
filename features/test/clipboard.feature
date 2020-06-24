Feature: Clipboard testing scenarios

  Scenario: random str
    Given a 5 character random string is stored into the clipboard
    Given a random string of type :dns is stored into the :dns_rand clipboard
    Then the expression should be true> cb.tmp.size == 5
    Then the expression should be true> cb.dns_rand.size == 8

  @admin
  Scenario: create volume and save id into clipboard
    Given I have a project
    And I have a 1 GB volume and save volume id in the :volume_id clipboard

  @admin
  Scenario: save volumed id from resource to clipboard
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I run oc create over "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | dynamic-pvc1-<%= project.name %> |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce                    |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                              |
    Then the step should succeed
    And the "dynamic-pvc1-<%= project.name %>" PVC becomes :bound
    And I save volume id from PV named "<%= pvc.volume_name(user: admin, cached: true) %>" in the :volumeID clipboard
