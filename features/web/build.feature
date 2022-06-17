Feature: build related feature on web console

  # @author yapei@redhat.com
  # @case_id OCP-11773
  Scenario: OCP-11773 Modify buildconfig settings for Dockerfile source
    Given I have a project
    When I run the :new_build client command with:
      | D     | FROM centos:7\nRUN yum install -y httpd |
      | to    | myappis                                 |
      | name  | myapp                                   |
    Then the step should succeed
    When I perform the :goto_buildconfig_configuration_tab web console action with:
      | project_name        | <%= project.name %>  |
      | bc_name             | myapp                |
    Then the step should succeed
    When I perform the :check_build_strategy web console action with:
      | build_strategy      | Docker               |
    Then the step should succeed
    When I perform the :check_buildconfig_dockerfile_config web console action with:
      | project_name        | <%= project.name %>  |
      | bc_name             | myapp                |
      | docker_file_content | FROM centos:7RUN yum install -y httpd |
    Then the step should succeed
    # edit bc webhook, will fail since Docker bc webhook is not configurable
    When I perform the :enable_webhook_build_trigger web console action with:
      | project_name        | <%= project.name %>  |
      | bc_name             | myapp                |
    Then the step should fail
    # edit bc Dockerfile content
    When I perform the :edit_buildconfig_dockerfile_content web console action with:
      | project_name           | <%= project.name %>  |
      | bc_name                | myapp                |
      | content | FROM centos:7RUN yum update httpd |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I perform the :check_buildconfig_dockerfile_config web console action with:
      | project_name        | <%= project.name %>  |
      | bc_name             | myapp                |
      | docker_file_content | FROM centos:7RUN yum update httpd |
    Then the step should succeed

  # @author xxia@redhat.com
  # @case_id OCP-12494
  Scenario: OCP-12494 Check build trigger info when the trigger is ImageChange on web
    Given I have a project
    When I run the :create client command with:
      | f    | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc528954/bc_imagechange.yaml |
    Then the step should succeed
    Given the "ruby-ex-1" build was created within 120 seconds
    When I perform the :check_build_trigger web console action with:
      | project_name      | <%= project.name %> |
      | bc_and_build_name | ruby-ex/ruby-ex-1   |
      | trigger_info      | Image change for ruby-22-centos7:latest |
    Then the step should succeed

