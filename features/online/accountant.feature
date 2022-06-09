Feature: ONLY Accountant console related feature's scripts in this file

  # @author xiaocwan@redhat.com
  # @case_id OCP-12754
  Scenario: OCP-12754 Cancel and resume service - UI
    Given I open accountant console in a browser
    When I run the :click_to_change_plan web action
    Then the step should succeed
    When I run the :click_cancel_your_service web action
    Then the step should succeed
    When I run the :cancel_your_service_with_wrong_username web action
    Then the step should succeed
    When I run the :check_keep_current_plan web action
    Then the step should succeed

    When I perform the :cancel_your_service_correctly web action with:
      | username | <%= user.name %> |
    Then the step should succeed
    When I perform the :click_resume_your_subscription_confirm web action with:
      | last_date | <%= last_second_of_month.strftime("%A, %B %d, %Y") %> |
    Then the step should succeed

  # @author yuwan@redhat.com
  # @case_id OCP-12758
  # @note this scenario requires a user who have pro cluster(1) left to resigster
  Scenario: OCP-12758 an existed Red Hat account's contact details can be pre-populated to accountant profile during registration
    Given I open accountant console in a browser
    When I run the :go_to_register_pro_cluster_page web action
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

