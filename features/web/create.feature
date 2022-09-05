Feature: create app on web console related

  # @author xxing@redhat.com
  # @case_id OCP-11171
  @smoke
  Scenario: OCP-11171:UserInterface Create application from image on web console
    Given I have a project
    Given I wait for the :create_app_from_image web console action to succeed with:
      | project_name | <%= project.name %>                        |
      | image_name   | python                                     |
      | image_tag    | latest                                     |
      | namespace    | openshift                                  |
      | app_name     | python-sample                              |
      | source_url   | https://github.com/sclorg/django-ex.git |
      | git_ref      | v1.0.1                                     |
    Given the "python-sample-1" build was created
    Given the "python-sample-1" build completed

  # @author xxing@redhat.com
  # @case_id OCP-11445
  Scenario: OCP-11445 Create application from template with invalid parameters on web console
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/ui/application-template-stibuild-without-customize-route.json |
    Then the step should succeed
    When I perform the :create_app_from_template_with_label web console action with:
      | project_name  | <%= project.name %>    |
      | template_name | ruby-helloworld-sample |
      | namespace     | <%= project.name %>    |
      | label_key     | /%^&   |
      | label_value   | value1 |
    Then the step should fail
    When I run the :confirm_errors_with_invalid_template_label web console action
    Then the step should succeed

  # @author wsun@redhat.com
  # @case_id OCP-12596
  Scenario: OCP-12596 Create the app with invalid name
    Given I have a project
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | nodejs-sample                              |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should succeed
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | AA                                         |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should fail
    When I get the html of the web page
    Then the output should contain:
      | Please enter a valid name. |
      | A valid name is applied to all generated resources. It is an alphanumeric (a-z, and 0-9) string with a maximum length of 24 characters, where the first character is a letter (a-z), and the '-' character is allowed anywhere except the first or last character. |
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | -test                                      |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should fail
    When I get the html of the web page
    Then the output should contain:
      | Please enter a valid name. |
      | A valid name is applied to all generated resources. It is an alphanumeric (a-z, and 0-9) string with a maximum length of 24 characters, where the first character is a letter (a-z), and the '-' character is allowed anywhere except the first or last character. |
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | test-                                      |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should fail
    When I get the html of the web page
    Then the output should contain:
      | Please enter a valid name. |
      | A valid name is applied to all generated resources. It is an alphanumeric (a-z, and 0-9) string with a maximum length of 24 characters, where the first character is a letter (a-z), and the '-' character is allowed anywhere except the first or last character. |
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | 123456789                                  |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should fail
    When I get the html of the web page
    Then the output should contain:
      | Please enter a valid name. |
      | A valid name is applied to all generated resources. It is an alphanumeric (a-z, and 0-9) string with a maximum length of 24 characters, where the first character is a letter (a-z), and the '-' character is allowed anywhere except the first or last character. |
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | nodejs-sample                              |
      | source_url   | https://github.com/sclorg/nodejs-ex.git |
    Then the step should fail
    When I get the html of the web page
    Then the output should contain:
      | This name is already in use within the project. Please choose a different name. |

  # @author etrott@redhat.com
  # @case_id OCP-10920
  Scenario: OCP-10920 Environment variables and label management in create app from image on web console
    Given I have a project
    When I perform the :create_app_from_image_check_label web console action with:
      | project_name | <%= project.name %>                         |
      | image_name   | php                                         |
      | image_tag    | latest                                      |
      | namespace    | openshift                                   |
      | app_name     | php                                         |
      | source_url   | https://github.com/sclorg/cakephp-ex.git |
      | bc_env_key   | BCkey1                                      |
      | bc_env_value | BCvalue1                                    |
      | dc_env_key   | DCkey1                                      |
      | dc_env_value | DCvalue1                                    |
      | label_key    | test1                                       |
      | label_value  | value1                                      |
    Then the step should succeed

    When I perform the :create_app_from_image_add_bc_env_vars web console action with:
      | bc_env_key   | BCkey2   |
      | bc_env_value | BCvalue2 |
    Then the step should succeed
    When I perform the :edit_env_var_value web console action with:
      | env_variable_name | BCkey1         |
      | new_env_value     | BCvalue1update |
    Then the step should succeed
    When I perform the :delete_env_var web console action with:
      | env_var_key | BCkey2 |
    Then the step should succeed

    When I perform the :create_app_from_image_add_dc_env_vars web console action with:
      | dc_env_key   | DCkey2   |
      | dc_env_value | DCvalue2 |
    Then the step should succeed
    When I perform the :create_app_from_image_add_dc_env_vars web console action with:
      | dc_env_key   | test3!#!   |
      | dc_env_value | testvalue3 |
    Then the step should succeed
    When I run the :confirm_errors_with_invalid_env_var web console action
    Then the step should succeed
    When I perform the :delete_env_var web console action with:
      | env_var_key | test3!#! |
    Then the step should succeed
    When I perform the :edit_env_var_value web console action with:
      | env_variable_name | DCkey2         |
      | new_env_value     | DCvalue2update |
    Then the step should succeed


    When I perform the :add_new_label web console action with:
      | label_key   | test2  |
      | label_value | value2 |
    Then the step should succeed
    When I perform the :add_new_label web console action with:
      | label_key   | test3!#! |
      | label_value | value3   |
    Then the step should succeed
    When I run the :confirm_errors_with_invalid_template_label web console action
    Then the step should succeed
    When I run the :check_create_button_disabled web console action
    Then the step should succeed
    When I perform the :delete_env_var web console action with:
      | env_var_key | test3!#! |
    Then the step should succeed
    When I perform the :edit_env_var_value web console action with:
      | env_variable_name | test2        |
      | new_env_value     | value2update |
    Then the step should succeed

    When I run the :create_app_from_image_submit web console action
    Then the step should succeed

    When I perform the :check_buildconfig_environment web console action with:
      | project_name  | <%= project.name %> |
      | bc_name       | php                 |
      | env_var_key   | BCkey1              |
      | env_var_value | BCvalue1update      |
    Then the step should succeed

    When I perform the :check_build_environment web console action with:
      | project_name      | <%= project.name %> |
      | bc_and_build_name | php/php-1           |
      | env_var_key       | BCkey1              |
      | env_var_value     | BCvalue1update      |
    Then the step should succeed

    When I perform the :check_dc_environment web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | php                 |
      | env_var_key   | DCkey1              |
      | env_var_value | DCvalue1            |
    Then the step should succeed
    When I perform the :check_dc_environment web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | php                 |
      | env_var_key   | DCkey2              |
      | env_var_value | DCvalue2update      |
    Then the step should succeed

    Given the "php-1" build completed
    Given a pod is present with labels:
      | deploymentconfig=php |
    When I perform the :check_deployment_environment web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | php                 |
      | dc_number     | 1                   |
      | env_var_key   | DCkey1              |
      | env_var_value | DCvalue1            |
    Then the step should succeed
    When I perform the :check_deployment_environment web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | php                 |
      | dc_number     | 1                   |
      | env_var_key   | DCkey2              |
      | env_var_value | DCvalue2update      |
    Then the step should succeed

    When I perform the :check_pod_environment web console action with:
      | project_name  | <%= project.name %> |
      | pod_name      | <%= pod.name %>     |
      | env_var_key   | DCkey1              |
      | env_var_value | DCvalue1            |
    Then the step should succeed
    When I perform the :check_pod_environment web console action with:
      | project_name  | <%= project.name %> |
      | pod_name      | <%= pod.name %>     |
      | env_var_key   | DCkey2              |
      | env_var_value | DCvalue2update      |
    Then the step should succeed

    # Laste step: Go through all resources and check their labels
    When I run the :get client command with:
      | resource | all                 |
      | l        | test1=value1        |
      | n        | <%= project.name %> |
    And the output should match:
      | (bc\|buildconfig[^ ]*)/php             |
      | build[^ ]*/php-1                       |
      | (is\|imagestream[^ ]*)/php             |
      | (dc\|deploymentconfig[^ ]*)/php        |
      | (rc\|replicationcontroller[^ ]*)/php-1 |
      | route[^ ]*/php                         |
      | (svc\|service[^ ]*)/php                |
      | (po\|pod[^ ]*)/<%= pod.name %>         |

  # @author yapei@redhat.com
  # @case_id OCP-15062
  Scenario: OCP-15062 Check Deploy Image and Import YAML from new landing page
    Given the master version >= "3.7"
    Given I have a project
    # deploy from image stream tag with customized env and labels
    When I perform the :deploy_from_image_stream_tag_with_normal_image_stream web console action with:
      | project_name      | <%= project.name %> |
      | namespace         | openshift           |
      | image_stream_name | python              |
    Then the step should succeed
    When I perform the :add_new_label web console action with:
      | label_key   | testname  |
      | label_value | testvalue |
    Then the step should succeed
    When I run the :click_deploy_button web console action
    Then the step should succeed
    And I wait for the "python" service to appear
    And I wait for the "python" dc to appear
    And a pod is present with labels:
      | deployment=python-1 |
      | testname=testvalue  |

    # Import YAML/JSON
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/ui/application-template-stibuild-without-customize-route.json"
    Then the step should succeed
    When I run the :goto_home_page web console action
    Then the step should succeed
    When I run the :click_import_yaml_json web console action
    Then the step should succeed
    When I perform the :create_from_file web console action with:
      | file_path | <%= File.join(localhost.workdir, "application-template-stibuild-without-customize-route.json") %> |
    Then the step should succeed
    When I run the :click_create_button web console action
    Then the step should succeed
    When I perform the :process_and_save_template web console action with:
      | process_template | false |
      | save_template    | true  |
    Then the step should succeed
    When I run the :get client command with:
      | resource | template |
    Then the step should succeed
    And the output should contain:
      | ruby-helloworld-sample |

