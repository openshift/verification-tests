@marketplace
Feature: Marketplace related scenarios

  # @author jiazha@redhat.com
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: upgrade Marketplace - prepare
    # Check Marketplace version
    Given the "marketplace" operator version matches the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4+, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # In 4.6-, Create a new OperatorSource. In 4.6 and 4.6+, there is no OperatorSource.
    Given I create a new OperatorSource
    # In 4.5-, Create a new CatalogSourceConfig. In 4.5 and 4.5+, there is no CatalogSourceConfig
    Given I create a new CatalogSourceConfig
    # Check if the marketplace works well
    And I wait up to 360 seconds for the steps to pass:
    """
    Given the marketplace works well
    """

  # @author jiazha@redhat.com
  # @case_id OCP-22618
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  @aws-upi
  @vsphere-ipi
  Scenario: upgrade Marketplace
    # Check Marketplace version after upgraded
    Given the "marketplace" operator version matches the current cluster version
    # Check cluster operator marketplace status
    Given the status of condition "Degraded" for "marketplace" operator is: False
    Given the status of condition "Progressing" for "marketplace" operator is: False
    Given the status of condition "Available" for "marketplace" operator is: True
    # In 4.4+, if exists csc or cutomize operatorsource objects, the status should be `False`
    Given the status of condition Upgradeable for marketplace operator as expected
    Given I switch to cluster admin pseudo user
    # Check if the marketplace works well
    And I wait up to 360 seconds for the steps to pass:
    """
    Given the marketplace works well
    """
