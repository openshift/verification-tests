  Feature: functions about notification_drawer

  # @author yapei@redhat.com
  # @case_id OCP-15231
  Scenario: OCP-15231 Check notification goes into drawer in its own project
    Given the master version >= "3.7"
    # Create 2 projects, add 'python' app to 1st project, add 'php' app to 2nd project
    Given I have a project
    Then evaluation of `project.name` is stored in the :proj1_name clipboard
    Given I create a new project
    Then evaluation of `project.name` is stored in the :proj2_name clipboard
    When I run the :new_app client command with:
      | image_stream | openshift/python:latest                    |
      | code         | https://github.com/sclorg/django-ex.git |
      | name         | python-sample                              |
      | n            | <%= cb.proj1_name %>                       |
    Then the step should succeed
    When I run the :new_app client command with:
      | image_stream | openshift/php:latest                         |
      | code         | https://github.com/sclorg/cakephp-ex.git  |
      | name         | php-sample                                   |
      | n            | <%= cb.proj2_name %>                         |
    Then the step should succeed

    # check notification event
    When I perform the :open_notification_drawer_for_one_project web console action with:
      | project_name | <%= cb.proj1_name %> |
    Then the step should succeed
    When I perform the :check_drawer_notification_content web console action with:
      | event_reason | Build Started   |
      | event_object | python-sample-1 |
    Then the step should succeed
    When I perform the :check_page_not_contain_text web console action with:
      | text | php |
    Then the step should succeed
    When I perform the :switch_project_in_project_lists web console action with:
      | current_project | <%= cb.proj1_name %> |
      | target_project  | <%= cb.proj2_name %> |
    Then the step should succeed
    When I perform the :check_drawer_notification_content web console action with:
      | event_reason | Build Started   |
      | event_object | php-sample-1    |
    Then the step should succeed
    When I perform the :check_page_not_contain_text web console action with:
      | text | python |
    Then the step should succeed
    Given the "php-sample-1" build finished
    When I perform the :check_zero_unread_in_drawer web console action with:
      | unread_num | 0 |
    Then the step should succeed
    When I run the :check_drawer_info_when_no_events web console action
    Then the step should succeed

