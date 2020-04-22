Feature: Check overview page
  # @author hasha@redhat.com
  # @case_id OCP-13641
  Scenario: Check app resources on overview page
    Given the master version >= "3.6"
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/ruby:latest                 |
      | app_repo     | https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    Given a pod is present with labels:
      | openshift.io/build.name=ruby-ex-1 |
    When I expose the "ruby-ex" service
    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_application_block_info_on_overview web console action with:
      | resource_name        | ruby-ex                            |
      | resource_type        | deployment                         |
      | project_name         | <%= project.name %>                |
      | build_num            | 1                                  |
      | route_url            | http://<%= route("ruby-ex").dns %> |
      | route_port_info      | 8080-tcp                           |
      | service_port_mapping | 8080/TCP (8080-tcp) 8080           |
      | container_image      | ruby-ex                            |
      | container_source     | Merge pull request                 |
      | container_ports      | 8080/TCP                           |
      | bc_name              | ruby-ex                            |
    Then the step should succeed

