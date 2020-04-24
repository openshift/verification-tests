Feature: check page info related
  # @author yapei@redhat.com
  # @case_id OCP-12625
  Scenario: Check home page to list user projects
    Given I login via web console
    When I run the :check_instructions_on_home_page web console action
    Then the step should succeed
    Given an 8 character random string of type :dns is stored into the :prj_name clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.prj_name %> |
    Then the step should succeed
    When I run the :check_project_list web console action
    Then the step should succeed
    When I get the html of the web page
    Then the output should contain:
      | <%= cb.prj_name %> |

  # @author yanpzhan@redhat.com
  # @case_id OCP-11219
  Scenario: Check storage page on web console
    Given I have a project
    When I perform the :check_empty_storage_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    Given I use the "<%= project.name %>" project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/nfs/claim-rwo-ui.json |
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

