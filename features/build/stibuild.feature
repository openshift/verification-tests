Feature: stibuild.feature

  # @author haowang@redhat.com
  # @case_id OCP-11099
  Scenario: OCP-11099 STI build with invalid context dir
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/python-27-rhel7-errordir-stibuild.json |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | python-sample-build |
    And the "python-sample-build-1" build was created
    And the "python-sample-build-1" build failed
    When I run the :get client command with:
      | resource | build |
    Then the output should contain:
      | InvalidContextDirectory |

  # @author xiuwang@redhat.com
  Scenario Outline: Trigger s2i/docker/custom build using additional imagestream
    Given I have a project
    And I run the :new_app client command with:
      | file | <template> |
    Then the step should succeed
    And the "sample-build-1" build was created
    When I run the :cancel_build client command with:
      | build_name | sample-build-1                  |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | myimage               |
      | from       | aosqe/ruby-22-centos7 |
      | confirm    | true                  |
    Then the step should succeed
    And the "sample-build-2" build was created
    When I run the :describe client command with:
      | resource | builds         |
      | name     | sample-build-2 |
    Then the step should succeed
    And the output should contain:
      |Build trigger cause:	Image change          |
      |Image ID:		aosqe/ruby-22-centos7 |
      |Image Name/Kind:	myimage:latest                |
    When I run the :start_build client command with:
      | buildconfig | sample-build |
    Then the step should succeed
    And the "sample-build-3" build was created
    When I get project builds
    Then the step should succeed
    And the output should not contain "sample-build-4"

    Examples:
      |template|
      |https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc498848/tc498848-s2i.json   | # @case_id OCP-12041
      |https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc498847/tc498847-docker.json| # @case_id OCP-11911
      |https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc498846/tc498846-custom.json| # @case_id OCP-11739

  # @author wewang@redhat.com
  # @case_id OCP-15464
  Scenario:Override incremental setting using --incremental flag when s2i build request
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | openshift/ruby:2.3~https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build completed
    When I run the :patch client command with:
      | resource      | bc                                                            |
      | resource_name | ruby-hello-world                                              |
      | p             | {"spec":{"strategy":{"sourceStrategy":{"incremental":true}}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig      |
      | name     | ruby-hello-world |
    Then the step should succeed
    Then the output should match "Incremental Build:\s+yes"
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | incremental | true             |
      Then the step should succeed
    When I run the :logs client command with:
      | resource_name | bc/ruby-hello-world |
    Then the output should contain:
      | save-artifacts: No such file or directory|
     When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | incremental | false            |
      Then the step should succeed
    When I run the :logs client command with:
      | resource_name | bc/ruby-hello-world |
    Then the output should not contain:
      | save-artifacts: No such file or directory|

