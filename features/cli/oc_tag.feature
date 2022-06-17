Feature: oc tag related scenarios

  # @author xxia@redhat.com
  # @case_id OCP-11496
  Scenario: OCP-11496 Tag an image into mutliple image streams
    Given I have a project
    When I run the :tag client command with:
      | source_type  | docker                     |
      | source       | docker.io/library/busybox:latest   |
      | dest         | mystream:latest            |
    Then the step should succeed
    # Cucumber runs steps fast. Need wait for the istag so that it really can be referenced by following steps
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | istag             |
      | resource_name | mystream:latest   |
    Then the step should succeed
    """

    When I run the :tag client command with:
      | source_type  | docker                     |
      | source       | docker.io/library/busybox:latest   |
      | dest         | mystream:tag               |
    Then the step should succeed
    # Same reason as above case. Need wait, instead of one-time check
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | is                |
    Then the step should succeed
    And the output should match "mystream.+tag,latest"
    """

    When I create a new project
    Then the step should succeed
    And I create a new project
    Then the step should succeed
    When I run the :tag client command with:
      | source_type  | istag                                 |
      | source       | <%= @projects[0].name %>/mystream:latest |
      | dest         | <%= @projects[0].name %>/mystream:tag1   |
      | dest         | <%= @projects[1].name %>/stream1:tag1  |
      | dest         | <%= @projects[2].name %>/stream2:tag2  |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | is                      |
      | namespace     | <%= @projects[0].name %> |
    Then the step should succeed
    And the output should match "mystream.+tag1,tag,latest"
    When I run the :get client command with:
      | resource      | is                      |
      | namespace     | <%= @projects[2].name %> |
    Then the step should succeed
    And the output should match "stream2.+tag2"

  # @author mcurlej@redhat.com
  # @case_id OCP-12154
  Scenario: OCP-12154 Tag should correctly add muptiple imagestreamtags to one imagestream
    Given I have a project
    When I run the :tag client command with:
      | source_type  | docker                  |
      | source       | openshift/origin:latest |
      | dest         | ruby:tip                |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | is   |
      | name     | ruby |
    Then the step should succeed
    And the output should match:
      | tip\s.*openshift\/origin:latest |
    When I run the :get client command with:
      | resource      | istag    |
      | resource_name | ruby:tip |
      | output        | yaml     |
    Then the step should succeed
    And the expression should be true> @result[:parsed].dig("image", "dockerImageLayers", 0, "size")
    When I run the :tag client command with:
      | source_type  | docker                  |
      | source       | openshift/origin:v1.2.0 |
      | dest         | ruby:another            |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | is   |
      | name     | ruby |
    Then the step should succeed
    And the output should match:
      | tip\s.*openshift\/origin:latest       |
      | another\s.*openshift\/origin:v1\.2\.0 |
    When I run the :get client command with:
      | resource      | istag        |
      | resource_name | ruby:another |
      | output        | yaml         |
    Then the step should succeed
    And the expression should be true> @result[:parsed].dig("image", "dockerImageLayers", 0, "size")
    When I run the :tag client command with:
      | source_type  | docker                |
      | source       | openshift/origin:fail |
      | dest         | ruby:fail             |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | is   |
      | name     | ruby |
    Then the step should succeed
    And the output should match:
      | tip\s.*openshift\/origin:latest    |
      | another\s.*openshift/origin:v1.2.0 |
      | fail\s.*openshift\/origin:fail     |
      | [Ii]mport failed                   |
    When I run the :get client command with:
      | resource      | istag     |
      | resource_name | ruby:fail |
      | output        | yaml      |
    Then the step should fail
    And the output should match:
      | Error from server |
      | ruby:fail         |
      | not found         |

