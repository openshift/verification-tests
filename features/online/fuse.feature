Feature: ONLY Fuse Plan related scripts in this file

  # @author yuwan@redhat.com
  # @case_id OCP-20439
  # @note this scenario requires a user who have pro cluster(1) left to resigster
  Scenario: OCP-20439 an existed Red Hat account's contact details can be pre-populated to accountant profile during registration - Fuse
    Given I open accountant console in a browser
    When I run the :go_to_register_fuse_profile_page web action
    Then the step should succeed
    Given I saved following keys to list in :regionid clipboard:
      | contact_region | |
      | billing_region | |
    When I repeat the following steps for each :rid in cb.regionid:
    """
    When I perform the :check_region_prepopulation web action with:
      | region_id | #{cb.rid} |
    Then the step should succeed
    """
    Given I saved following keys to list in :countryid clipboard:
      | contact_country | |
      | billing_country | |
    When I repeat the following steps for each :cid in cb.countryid:
    """
    When I perform the :check_country_prepopulation web action with:
      | country_id | #{cb.cid} |
    Then the step should succeed
    """
    Given I saved following keys to list in :elementid clipboard:
      | contact_first_name   | |
      | contact_last_name    | |
      | contact_address1     | |
      | contact_city         | |
      | contact_postcode     | |
      | contact_phone_number | |
      | billing_first_name   | |
      | billing_last_name    | |
      | billing_address1     | |
      | billing_city         | |
      | billing_postcode     | |
      | billing_phone_number | |
    When I repeat the following steps for each :id in cb.elementid:
    """
    When I perform the :check_input_profile_prepopulation web action with:
      | checkpoint_id | #{cb.id} |
    Then the step should succeed
    """

