Feature: oc tag related scenarios
  # @author mcurlej@redhat.com
  # @case_id OCP-12154
  Scenario: Tag should correctly add muptiple imagestreamtags to one imagestream
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

