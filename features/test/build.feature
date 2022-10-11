Feature: build test related

  Scenario: Print build logs when buid failed
    Given I have a project
    When I create a new application with:
      | image_stream | openshift/ruby~https://github.com/openshift/fakerepo |
      | name         | ruby-sample  |
    Then the step should succeed
    Given the "ruby-sample-1" build completed
