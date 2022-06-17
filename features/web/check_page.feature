Feature: check page info related

  # @author wsun@redhat.com
  # @case_id OCP-10605
  @smoke
  Scenario: OCP-10605 Check Events page
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/nodejs:latest                |
      | code         | https://github.com/sclorg/nodejs-ex |
      | name         | nodejs-sample                          |
    Then the step should succeed
    When I perform the :create_from_image_complete_info_on_next_page web console action with:
      | project_name | <%= project.name %> |
      | image_name   | nodejs              |
      | image_tag    | 0.10                |
      | namespace    | openshift           |
      | app_name     | nodejs-sample       |
    Then the step should succeed
    When I perform the :check_events_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id OCP-12625
  Scenario: OCP-12625 Check home page to list user projects
    Given I login via web console
    When I run the :check_instructions_on_home_page web console action
    Then the step should succeed
    Given an 8 character random string of type :dns is stored into the :prj_name clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.prj_name %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.prj_name %> |
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id OCP-11219
  Scenario: OCP-11219 Check storage page on web console
    Given I have a project
    When I perform the :check_empty_storage_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    Given I use the "<%= project.name %>" project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/nfs/claim-rwo-ui.json |
    Then the step should succeed

    When I get project persistentvolumeclaims as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :pvc_name clipboard

    Then I perform the :check_pvcs_on_storage_page web console action with:
      | project_name | <%= project.name %> |
      | pvc_name     | <%= cb.pvc_name %> |
    Then the step should succeed

    When I perform the :check_one_pvc_detail web console action with:
      | project_name | <%= project.name %> |
      | pvc_name     | <%= cb.pvc_name %> |
    Then the step should succeed

