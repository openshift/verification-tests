Feature: stibuild.feature
  # @author xiuwang@redhat.com
  Scenario Outline: Trigger s2i/docker/custom build using additional imagestream
    Given I have a project
    Given I obtain test data file "templates/<template>"
    And I run the :new_app client command with:
      | file | <template> |
    Then the step should succeed
    And the "sample-build-1" build was created
    When I run the :cancel_build client command with:
      | build_name | sample-build-1                  |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | myimage                                       |
      | from       | registry.redhat.io/rhscl/ruby-27-rhel7:latest |
      | confirm    | true                                          |
    Then the step should succeed
    And the "sample-build-2" build was created
    When I run the :describe client command with:
      | resource | builds         |
      | name     | sample-build-2 |
    Then the step should succeed
    And the output should contain:
      |Build trigger cause:	Image change                           |
      |Image ID:		registry.redhat.io/rhscl/ruby-27-rhel7 |
      |Image Name/Kind:	myimage:latest                                 |
    When I run the :start_build client command with:
      | buildconfig | sample-build |
    Then the step should succeed
    And the "sample-build-3" build was created
    When I get project builds
    Then the step should succeed
    And the output should not contain "sample-build-4"

    Examples:
      | template          |
      | ocp12041-s2i.json | # @case_id OCP-12041

  # @author wzheng@redhat.com
  # @case_id OCP-30858
  Scenario: STI build with dockerImage with specified tag
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | centos/ruby-25-centos7                  |
      | app_repo     | https://github.com/openshift-qe/ruby-ex |
    Then the step should succeed
    And the "ruby-ex-1" build completes
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                      |
      | resource_name | ruby-ex                                                                                                                                          |
      | p             | {"spec": {"strategy": {"sourceStrategy": {"from": {"kind": "DockerImage","name": "quay.io/openshifttest/ruby-25-centos7@sha256:575194aa8be12ea066fc3f4aa9103dcb4291d43f9ee32e4afe34e0063051610b"}}},"type": "Source"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-ex |
    Then the step should succeed
    And the "ruby-ex-2" build completes
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                     |
      | resource_name | ruby-ex                                                                                                                                         |
      | p             | {"spec": {"strategy": {"sourceStrategy": {"from": {"kind": "DockerImage","name": "quay.io/openshifttest/ruby-25-centos7:error"}}},"type": "Source"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-ex |
    Then the step should succeed
    And the "ruby-ex-3" build failed
    When I run the :describe client command with:
      | resource | build     |
      | name     | ruby-ex-3 |
    Then the step should succeed
    And the output should contain "error"

  # @author wzheng@redhat.com
  # @case_id OCP-22596
  Scenario: Create app with template eap72-basic-s2i with jbosseap rhel7 image
    Given I have a project
    When I run the :new_app client command with:
      | template | eap72-basic-s2i |
    Then the step should succeed
    Given the "eap-app-1" build was created
    And the "eap-app-1" build completed
    Given 1 pod becomes ready with labels:
      | application=eap-app |

  # @author xiuwang@redhat.com
  # @case_id OCP-28891
  Scenario: Test s2i build in disconnect cluster
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git               |
      | e        | REQUIRE_SERVER_AUTH= |
      | e        | REQUIRE_GIT_AUTH=    |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    Given I obtain test data dir "build/httpd-ex.git"
    When I run the :cp client command with:
      | source | httpd-ex.git |
      | dest   | <%= pod.name %>:/var/lib/git/                       |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | openshift/httpd:latest~http://<%= cb.git_route %>/httpd-ex.git |
    Then the step should succeed
    Given the "httpd-ex-1" build was created
    And the "httpd-ex-1" build completes
