Feature: image stream related code test

  Scenario: wait image stream to become ready for use
    Given I have a project
    And I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Given the "ruby-22-centos7" image stream becomes ready
    When I run the :start_build client command with:
      | buildconfig |  ruby-sample-build |
    Then the step should succeed
