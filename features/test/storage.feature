Feature: some storage related scenarios

  # @author mcurlej@redhat.com
  @admin
  Scenario: test openstack rest api
    Given I have a project
    Given I obtain test data file "storage/ebs/dynamic-provisioning-pvc.json"
    When I run the :create client command with:
      | f | dynamic-provisioning-pvc.json |
    Then the step should succeed
    And the "ebsc" PVC becomes :bound
    And evaluation of `pvc.volume_name(user: user)` is stored in the :volume_name clipboard
    And evaluation of `env.iaas[:type]=="gce"?"READY":"available"` is stored in the :status clipboard
    # ready statuses: GCE -> READY, AWS -> available, OS -> available
    When I verify that the IAAS volume for the "<%= cb.volume_name %>" PV becomes "<%= cb.status %>"
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | pvc |
      | all         |     |
    Then the step should succeed
    And I verify that the IAAS volume for the "<%= cb.volume_name%>" PV was deleted

  @admin
  Scenario: Store PV into clipboard
    Given admin stores all persistentvolumes to the clipboard

  @admin
  Scenario: test LocalVolumeDiscoveryResult support
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-local-storage" project
    Given I save all localvolumediscoveryresults for my cluster to clipboard
