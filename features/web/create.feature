Feature: create app on web console related
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

