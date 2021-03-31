Feature: buildconfig.feature

  # @author wzheng@redhat.com
  # @case_id OCP-12121
  Scenario: Start build from buildConfig/build
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/ruby:latest |
      | app_repo     | https://github.com/openshift/ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build finished
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created
    And the "ruby-hello-world-2" build completed
    When I run the :start_build client command with:
      | from_build | ruby-hello-world-2 |
    Then the step should succeed
    And the "ruby-hello-world-3" build was created
    And the "ruby-hello-world-3" build completed

  # @author haowang@redhat.com
  # @case_id OCP-10667
  Scenario: Rebuild image when the underlying image changed for Docker build
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    Then the "ruby-25-centos7" image stream was created
    And the "ruby-hello-world-1" build was created
    When I run the :tag client command with:
      | source_type | docker                 |
      | source      | openshift/ruby:2.7     |
      | dest        | ruby-25-centos7:latest |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created

  # @author dyan@redhat.com
  # @case_id OCP-12020
  Scenario: Trigger chain builds from a image update
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | centos/ruby-25-centos7:latest~https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    Then the "ruby-25-centos7" image stream was created
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build becomes :complete
    When I run the :new_build client command with:
      | image_stream | ruby-hello-world                     |
      | code         | https://github.com/sclorg/ruby-ex    |
      | name         | ruby-ex                              |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    When I run the :tag client command with:
      | source_type      | docker                 |
      | source           | openshift/ruby:2.5     |
      | dest             | ruby-25-centos7:latest |
      | reference_policy | local                  |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created
    When the "ruby-hello-world-2" build becomes :complete
    Then the "ruby-ex-2" build was created

  # @author haowang@redhat.com
  Scenario Outline: Build with images pulled from private repositories
    Given I have a project
    When I run the :create_secret client command with:
     | name        | pull                                                                            |
     | secret_type | generic                                                                         |
     | from_file   | .dockercfg=<%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
     | type        | kubernetes.io/dockercfg                                                         |
    Then the step should succeed
    Given I obtain test data file "build/ocp11474/<template>"
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    Then the "ruby-sample-build-1" build completes

    Examples:
      | template                  |
      | test-buildconfig-s2i.json | # @case_id OCP-11474

  # @author xiuwang@redhat.com
  # @case_id OCP-12057
  Scenario: Using secret to pull a docker image which be used as source input
    Given I have a project
    When I run the :create_secret client command with:
     | name        | pull                                                                            |
     | secret_type | generic                                                                         |
     | from_file   | .dockercfg=<%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
     | type        | kubernetes.io/dockercfg                                                         |
    Then the step should succeed
    Given I obtain test data file "templates/OCP-12057/application-template-stibuild_pull_private_sourceimage.json"
    When I run the :new_app client command with:
     | file | application-template-stibuild_pull_private_sourceimage.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given a pod becomes ready with labels:
     | name=frontend |
    When I execute on the pod:
     | ls | openshiftqedir |
    Then the step should succeed
    And the output should contain:
     | app-root |
