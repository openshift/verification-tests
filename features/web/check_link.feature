Feature: Check links in Openshift

  # @author yapei@redhat.com
  # @case_id OCP-9770
  Scenario: OCP-9770 check doc links in web
    Given I store master major version in the clipboard
    # check documentation link in getting started instructions
    When I perform the :check_default_documentation_link_in_get_started web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed

    # check Documentation link on /console help
    When I perform the :check_default_documentation_link_in_console_help web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed

    # check docs link in about page
    When I perform the :check_default_documentation_link_in_about_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed
    When I perform the :check_cli_reference_doc_link_in_about_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed
    When I perform the :check_basic_cli_reference_doc_link_in_about_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed

    # check docs link on command line page
    When I perform the :check_get_started_with_cli_doc_link_in_cli_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed
    When I perform the :check_cli_reference_doc_link_in_cli_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed
    When I perform the :check_basic_cli_reference_doc_link_in_cli_page web console action with:
      | master_version | <%= cb.master_version %> |
    Then the step should succeed

    # check doc link on next step page
    Given I have a project
    When I perform the :check_documentation_link_in_next_step_page web console action with:
      | master_version | <%= cb.master_version %>               |
      | project_name   | <%= project.name %>                    |
      | image_name     | nodejs                                 |
      | image_tag      | latest                                 |
      | namespace      | openshift                              |
      | app_name       | nodejs-sample                          |
      | source_url     | https://github.com/sclorg/nodejs-ex |
    Then the step should succeed

    # check docs link about build
    When I perform the :check_webhook_trigger_doc_link_in_bc_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | bc_name        | nodejs-sample            |
    Then the step should succeed
    When I perform the :check_start_build_doc_link_in_bc_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | bc_name        | nodejs-sample            |
    Then the step should succeed

    # check doc link about deployment
    When I perform the :check_documentation_link_in_dc_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | dc_name        | nodejs-sample            |
    Then the step should succeed

    # check doc links on create route page
    When I perform the :check_route_type_doc_link_on_create_route_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
    Then the step should succeed

    # check doc links about pv
    When I perform the :check_pv_doc_link_on_attach_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | dc_name        | nodejs-sample            |
    Then the step should succeed

    # check doc link about compute resource
    When I perform the :check_compute_resource_doc_link_on_set_limit_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | dc_name        | nodejs-sample            |
    Then the step should succeed
  
    # check doc link about health check
    When I perform the :check_health_check_doc_link_on_edit_health_check_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | dc_name        | nodejs-sample            |
    Then the step should succeed

    # check doc link about autoscaler
    When I perform the :check_autoscaler_doc_link_on_add_autoscaler_page web console action with:
      | master_version | <%= cb.master_version %> |
      | project_name   | <%= project.name %>      |
      | dc_name        | nodejs-sample            |
    Then the step should succeed

