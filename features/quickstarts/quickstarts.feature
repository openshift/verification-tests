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
      | case_id                 | template                 | buildcfg                 | output      | podno |
      | OCP-12296:ImageRegistry | rails-postgresql-example | rails-postgresql-example | Rails       | 2     | # @case_id OCP-12296
      | OCP-13749:ImageRegistry | dotnet-example           | dotnet-example           | ASP.NET     | 1     | # @case_id OCP-13749
      | OCP-17826:ImageRegistry | openjdk18-web-basic-s2i  | openjdk-app              | Hello World | 1     | # @case_id OCP-17826
