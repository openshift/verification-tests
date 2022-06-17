Feature: Testing registry

  # @author etrott@redhat.com
  # @case_id OCP-10224
  @admin
  Scenario: OCP-10224 Login and logout of standalone registry console
    Given I have a project
    And I open registry console in a browser

    When I run the :click_images_link_in_iframe web action
    Then the step should succeed
    When I run the :check_no_images_on_images_page_in_iframe web action
    Then the step should succeed

    When I run the :goto_registry_console web action
    Then the step should succeed
    When I run the :click_images_link_in_iframe web action
    Then the step should succeed
    When I run the :check_no_images_on_images_page_in_iframe web action
    Then the step should succeed

    When I run the :logout web action
    Then the step should succeed
    When I run the :click_login_again web action
    Then the step should succeed
    When I perform login to registry console in the browser
    Then the step should succeed
    When I run the :click_images_link_in_iframe web action
    Then the step should succeed
    When I run the :check_no_images_on_images_page_in_iframe web action
    Then the step should succeed

    When I run the :logout web action
    Then the step should succeed
    When I run the :goto_registry_console web action
    Then the step should succeed

    When I perform login to registry console in the browser
    Then the step should succeed
    When I run the :click_images_link_in_iframe web action
    Then the step should succeed
    When I run the :check_no_images_on_images_page_in_iframe web action
    Then the step should succeed

