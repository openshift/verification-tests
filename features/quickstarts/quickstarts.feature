Feature: quickstarts.feature

  # @author haowang@redhat.com
  @inactive
  Scenario Outline: quickstart test
    Given I have a project
    When I run the :new_app client command with:
      | template | <template> |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    And I wait for the "<buildcfg>" service to become ready up to 300 seconds
    Then I wait for a web server to become available via the "<buildcfg>" route
    Then the output should contain "<output>"

    Examples: OS Type
      | template                 | buildcfg                 | output      | podno |
      | rails-postgresql-example | rails-postgresql-example | Rails       | 2     | # @case_id OCP-12296
      | dotnet-example           | dotnet-example           | ASP.NET     | 1     | # @case_id OCP-13749
      | openjdk18-web-basic-s2i  | openjdk-app              | Hello World | 1     | # @case_id OCP-17826
