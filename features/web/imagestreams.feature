Feature: check image streams page

  # @author yapei@redhat.com
  # @case_id OCP-10738
  @smoke
  Scenario: OCP-10738 check image stream page
    Given I have a project
    When I perform the :check_empty_image_streams_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    # create image streams via CLI
    Given I use the "<%= project.name %>" project
    Then I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
    When I run the :get client command with:
      | resource | is |
    Then the output should match:
      | jenkins |
      | mongodb |
      | mysql   |
      | nodejs  |
      | perl    |
      | php     |
      | postgresql |
      | python  |
      | ruby    |
    # check all image stream displayed well on web
    When I perform the :check_image_streams web console action with:
      | is_name | jenkins |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | mongodb |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | mysql |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | nodejs |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | perl |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | php |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | postgresql |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | python |
    Then the step should succeed
    When I perform the :check_image_streams web console action with:
      | is_name | ruby |
    Then the step should succeed
    # check one specific image
    When I perform the :check_one_image_stream web console action with:
      | project_name | <%= project.name %> |
      | image_name   |  nodejs |
    Then the step should succeed
    When I get the html of the web page
    Then the output should not match:
      | openshift.io/image.dockerRepositoryCheck |
    # delete one image stream via CLI
    When I run the :delete client command with:
      | object_type | is |
      | object_name_or_id | php |
    Then the output should match:
      | imagestream "php" deleted |
    # check deleted image stream on web
    When I perform the :check_deleted_image_stream web console action with:
      | project_name | <%= project.name %> |
      | image_name   | php  |
    Then the step should succeed

