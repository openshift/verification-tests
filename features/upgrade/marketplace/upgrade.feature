@marketplace
Feature: Marketplace related scenarios
    
  # @author jiazha@redhat.com
  # @case_id OCP-22618
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: upgrade Marketplace - prepare
    # Check Marketplace version
    Given the "marketplace" operator version matchs the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # Create a new OperatorSource
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/olm/operatorsource-template.yaml |
      | p | NAME=test-operators                                                                                 |
      | p | SECRET=                                                                                             |
      | p | DISPLAYNAME=Test Operators                                                                          |
      | p | REGISTRY=jiazha                                                                                     |
    Then the step should succeed
    # Create a new CatalogSourceConfig
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/olm/csc-template.yaml            |
      | p | DISPLAYNAME=CSC Operators                                                                           |
    Then the step should succeed
    # Check if the marketplace works well
    And I wait up to 180 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource       | packagemanifest |
      | all_namespaces | true            |
    Then the output should contain:
      | Community Operators  |
      | Red Hat Operators    |
      | Certified Operators  |
      | Test Operators       |
      | CSC Operators        |
    """
    
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: upgrade Marketplace
    # Check Marketplace version after upgraded
    Given the "marketplace" operator version matchs the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # Check if the marketplace works well
    And I wait up to 180 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource       | packagemanifest |
      | all_namespaces | true            |
    Then the output should contain:
      | Community Operators  |
      | Red Hat Operators    |
      | Certified Operators  |
      | Test Operators       |
      | CSC Operators        |
    """
