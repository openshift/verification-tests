Feature: bc/dc hooks related

  # @author xxing@redhat.com
  # @case_id OCP-11033
  Scenario: OCP-11033 Show hooks of recreate strategy DC
    Given the master version > "3.4"
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/ui/application-template-stibuild-without-customize-route.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/pre-post-hook-snippets.yaml"
    When I run the :patch client command with:
      | resource      | dc                                              | 
      | resource_name | database                                        |
      | p             | <%= File.read("pre-post-hook-snippets.yaml") %> |
    Then the step should succeed
    When I perform the :check_dc_loaded_completely web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
    Then the step should succeed
    When I perform the :check_dc_hook_common_settings_from_dc_page web console action with:
      | hook_type      | pre                      |
      | hook_name      | Pre Hook                 |
      | hook_action    | Tag the image            |
      | failure_policy | Abort                    |
      | container_name | ruby-helloworld-database |
    Then the step should succeed
    When I perform the :check_dc_hook_with_tagimage_action_from_dc_page web console action with:
      | hook_type      | pre       |
      | istag_name     | myis:tag1 |
    Then the step should succeed
    When I perform the :check_dc_hook_common_settings_from_dc_page web console action with:
      | hook_type      | mid                      |
      | hook_name      | Mid Hook                 |
      | hook_action    | Run a command            |
      | failure_policy | Abort                    |
      | container_name | ruby-helloworld-database |
    Then the step should succeed
    When I perform the :check_dc_hook_with_execnewpod_action_from_dc_page web console action with:
      | hook_type    | mid                       |
      | hook_command | /bin/true                 |
      | env_var      | CUSTOM_VAR2=custom_value2 |
      | volume_name  | ruby-helloworld-data      |
    Then the step should succeed
    When I perform the :check_dc_hook_common_settings_from_dc_page web console action with:
      | hook_type      | post                     |
      | hook_name      | Post Hook                |
      | hook_action    | Run a command            |
      | failure_policy | Ignore                   |
      | container_name | ruby-helloworld-database |
    Then the step should succeed
    When I perform the :check_dc_hook_with_execnewpod_action_from_dc_page web console action with:
      | hook_type    | post                                                                                    |
      | hook_command | /bin/true,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb |
      | env_var      | CUSTOM_VAR1=custom_value1,CUSTOM_VAR2=custom_value2,CUSTOM_VAR3=custom_value3           |
      | volume_name  | ruby-helloworld-data                                                                    |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | dc                                                    |
      | resource_name | database                                              |
      | p             | {"spec":{"strategy":{"recreateParams":{"pre":null}}}} |
    Then the step should succeed
    When I perform the :check_dc_loaded_completely web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
    Then the step should succeed
    When I perform the :check_dc_hook_missing_from_dc_page web console action with:
      | hook_type | pre      |
      | hook_name | Pre Hook |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | dc                                                                |
      | resource_name | database                                                          |
      | p             | {"spec":{"strategy":{"recreateParams":{"mid":null,"post":null}}}} |
    Then the step should succeed
    When I perform the :check_dc_loaded_completely web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | database            |
    Then the step should succeed
    When I run the :check_dc_hook_part_missing_from_dc_page web console action
    Then the step should succeed

