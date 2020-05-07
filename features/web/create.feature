Feature: create app on web console related
  # @author wsun@redhat.com
  # @case_id OCP-12596
  Scenario: Create the app with invalid name
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

  # @author yapei@redhat.com
  # @case_id OCP-15062
  Scenario: Check Deploy Image and Import YAML from new landing page
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
    Given I obtain test data file "templates/ui/application-template-stibuild-without-customize-route.json"
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

