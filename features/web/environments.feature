Feature: env related feature

  # @author yanpzhan@redhat.com
  # @case_id OCP-15442
  Scenario: OCP-15442 Support add configmap/secret with EnvForm format on env page
    Given I have a project
    When I run the :secrets client command with:
      | action | new        |
      | name   | secretone  |
      | source | /dev/null  |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/configmap/configmap-example.yaml |
    Then the step should succeed
    When I run the :run client command with:
      | name   | myrun                 |
      | image  | aosqe/hello-openshift |
      | limits | memory=256Mi          |
    Then the step should succeed

    When I perform the :goto_one_dc_environment_tab web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | myrun               |
    Then the step should succeed
    When I perform the :add_all_var_from_configmap_or_secret web console action with:
      | resource_name | secretone |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed

    When I perform the :check_view_details_on_env_tab web console action with:
      | text | Secret Details |
    Then the step should succeed

    When I perform the :add_all_var_from_configmap_or_secret web console action with:
      | resource_name | example-config |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_view_details_on_env_tab web console action with:
      | text | Config Map Details |
    Then the step should succeed

    When I perform the :delete_env_var_from_configmap_or_secret web console action with:
      | env_var_key | example-config |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_page_not_contain_text web console action with:
      | text | example-config |
    Then the step should succeed

    When I perform the :add_all_var_from_configmap_or_secret web console action with:
      | resource_name | example-config |
    Then the step should succeed
    When I run the :click_clear_changes web console action
    Then the step should succeed
    # The following step would fail on 3.7 due to existing bug: https://bugzilla.redhat.com/show_bug.cgi?id=1515527
    When I perform the :check_page_not_contain_text web console action with:
      | text | example-config |
    Then the step should succeed

