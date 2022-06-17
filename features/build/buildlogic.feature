Feature: buildlogic.feature

  # @author haowang@redhat.com
  # @case_id OCP-11545
  Scenario: OCP-11545 Build with specified Dockerfile via new-build -D
    Given I have a project
    When I run the :new_build client command with:
      | D    | FROM centos:7\nRUN echo "hello" |
      | to   | myappis                         |
      | name | myapp                           |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed

  # @author xiazhao@redhat.com
  # @case_id OCP-11170
  Scenario: OCP-11170 Result image will be tried to push after multi-build
    Given I have a project
    When I run the :new_app client command with:
      | file |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/php-55-rhel7-stibuild.json |
    Then the step should succeed
    # The 1st build should be triggered automatically
    And the "php-sample-build-1" build was created
    # Trigger the 2nd build in order for doing multi-builds
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    And the "php-sample-build-2" build was created
    # Wait for the first 2 builds finished
    And the "php-sample-build-1" build finished
    And the "php-sample-build-2" build finished
    # Trigger the 3rd build, it should succeed
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    And the "php-sample-build-3" build was created
    And the "php-sample-build-3" build completed

  # @author gpei@redhat.com
  # @case_id OCP-11767
  Scenario: OCP-11767 Create build without output
    Given I have a project
    When I run the :new_build client command with:
      | app_repo  | centos/ruby-23-centos7~https://github.com/openshift/ruby-hello-world.git |
      | no-output | true                                                                 |
      | name      | myapp                                                                |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed

  # @author yantan@redhat.com
  # @case_id OCP-10799
  Scenario: OCP-10799 Create new build config use dockerfile with source repo
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world   |
      | D        | FROM centos/ruby-22-centos7:latest\nRUN echo ok |
    Then the step should succeed
    When I get project buildconfigs as YAML
    Then the step should succeed
    Then the output should match:
      | dockerfile   |
      | FROM centos/ruby-22-centos7:latest                 |
      | RUN echo ok  |
      | uri: https://github.com/openshift/ruby-hello-world |
      | type: [Gg]it |
    When I get project build
    Then the "ruby-hello-world-1" build completed

  # @author haowang@redhat.com
  # @case_id OCP-11740
  Scenario: OCP-11740 Prevent STI builder images from running as root - using onbuild image
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499516/test-buildconfig-onbuild-user0.json |
    Then the step should succeed
    Given the "ruby-sample-build-onbuild-user0-1" build was created
    And the "ruby-sample-build-onbuild-user0-1" build failed
    When I run the :build_logs client command with:
      | build_name  | ruby-sample-build-onbuild-user0-1 |
    Then the output should contain:
      |  not allowed |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499516/test-buildconfig-onbuild-userdefault.json |
    Then the step should succeed
    Given the "ruby-sample-build-onbuild-userdefault-1" build was created
    And the "ruby-sample-build-onbuild-userdefault-1" build failed
    When I run the :build_logs client command with:
      | build_name  | ruby-sample-build-onbuild-userdefault-1 |
    Then the output should contain:
      |  not allowed |

  # @author haowang@redhat.com
  Scenario Outline: ForcePull image for build
    Given I have a project
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build becomes :running
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Force Pull:\s+(true\|yes)|

    Examples:
      | template                                                                                                                    |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-docker-ImageStream.json      | # @case_id OCP-10651
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-s2i-ImageStream.json         | # @case_id OCP-11148
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-docker-dockerimage.json      | # @case_id OCP-10652
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-s2i-dockerimage.json         | # @case_id OCP-11149

  # @author yantan@redhat.com
  # @case_id OCP-10745
  Scenario: OCP-10745 Build with specified Dockerfile to image with same image name via new-build
    Given I have a project
    When I run the :new_build client command with:
      | D | FROM centos:7\nRUN yum install -y httpd |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc     |
      | name     | centos |
    Then the output should match:
      | From Image:\s+ImageStreamTag centos:7     |
      | Output to:\s+ImageStreamTag centos:latest |
    Given the "centos-1" build becomes :complete
    When I run the :new_build client command with:
      | D    | FROM centos:7\nRUN yum install -y httpd |
      | to   | centos:7                                |
      | name | myapp                                   |
    And I get project bc
    Then the output should contain:
      | myapp |
    Given the "myapp-1" build becomes :complete
    And the "myapp-2" build becomes :complete
    And the "myapp-3" build becomes :running
    When I run the :new_build client command with:
      | code         | https://github.com/sclorg/nodejs-ex.git    |
      | image_stream | openshift/nodejs:0.10                         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby:2.0                            |
      | to           | centos:7                                      |
    Then the step should fail
    And the output should contain:
      | error |

  # @author haowang@redhat.com
  # @case_id OCP-11720
  Scenario: OCP-11720 Build from private git repo with/without ssh key
    Given I have a project
    And I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :oc_secrets_new_sshauth client command with:
      | ssh_privatekey | secret   |
      | secret_name    | mysecret |
    Then the step should succeed
    When I execute on the pod:
      | bash |
      | -c   |
      | cd /repos/ && rm -rf sample.git && git clone --bare https://github.com/openshift/ruby-hello-world sample.git |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | openshift/ruby:2.2                            |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | ruby-hello-world                              |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build completed
    When I run the :patch client command with:
      | resource      | buildconfig                                              |
      | resource_name | ruby-hello-world                                         |
      | p             | {"spec":{"source":{"git":{"uri":"<%= cb.git_repo %>"}}}} |
    Then the step should succeed
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the "ruby-hello-world-2" build was created
    Then the "ruby-hello-world-2" build failed
    When I run the :patch client command with:
      | resource      | buildconfig                                              |
      | resource_name | ruby-hello-world                                         |
      | p             | {"spec":{"source":{"sourceSecret":{"name":"mysecret"}}}} |
    Then the step should succeed
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the "ruby-hello-world-3" build was created
    Then the "ruby-hello-world-3" build completed

  # @author yantan@redhat.com
  # @case_id OCP-11896
  Scenario: OCP-11896 Create new-app from private git repo with ssh key
    Given I have a project
    When I run the :new_app client command with:
      | image_stream   | openshift/perl:5.20       |
      | code           | https://github.com/sclorg/s2i-perl-container.git |
      | context_dir    | 5.20/test/sample-test-app/|
    Then the step should succeed
    Given the "s2i-perl-container-1" build completes
    And I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :oc_secrets_new_sshauth client command with:
      | ssh_privatekey | secret   |
      | secret_name    | mysecret |
    When I execute on the pod:
      | bash           |
      | -c             |
      | cd /repos/ && rm -rf sample.git && git clone --bare https://github.com/sclorg/s2i-perl-container sample.git |
    Then the step should succeed
    When I run the :patch client command with:
      | resource       | buildconfig        |
      | resource_name  | s2i-perl-container |
      | p              | {"spec":{"source":{"git":{"uri":"<%= cb.git_repo %>"},"sourceSecret":{"name":"mysecret"}}}} |
    Then the step should succeed
    And I run the :start_build client command with:
      | buildconfig    | s2i-perl-container |
    Then the "s2i-perl-container-2" build was created
    Then the "s2i-perl-container-2" build completes
    When I expose the "s2i-perl-container" service
    Then I wait for a web server to become available via the "s2i-perl-container" route

  # @author dyan@redhat.com
  # @case_id OCP-13683
  Scenario: OCP-13683 Check s2i build substatus and times
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc470422/application-template-stibuild.json|
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Duration:\s+(\d+m)?\d+s        |
      | FetchInputs:\s+(\d+m)?\d+s     |
      | CommitContainer:\s+(\d+m)?\d+s |
      | Assemble:\s+(\d+m)?\d+s        |
      | PostCommit:\s+(\d+m)?\d+s      |
      | PushImage:\s+(\d+m)?\d+s       |

  # @author dyan@redhat.com
  # @case_id OCP-13684
  Scenario: OCP-13684 Check docker build substatus and times
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Duration:\s+(\d+m)?\d+s    |
      | FetchInputs:\s+(\d+m)?\d+s |
      | Build:\s+(\d+m)?\d+s       |
      | PostCommit:\s+(\d+m)?\d+s  |
      | PushImage:\s+(\d+m)?\d+s   |

  # @author xiuwang@redhat.com
  # @case_id OCP-13914
  Scenario: OCP-13914 Prune old builds automaticly
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | ruby                                          |
      | code         | https://github.com/openshift/ruby-hello-world |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | buildconfig      |
      | resource_name | ruby-hello-world |
      | o             | yaml             |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["spec"]["failedBuildsHistoryLimit"] == 5
    And the expression should be true> @result[:parsed]["spec"]["successfulBuildsHistoryLimit"] == 5
    Given the "ruby-hello-world-1" build completed
    Given I run the steps 5 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-6" build completed
    Then I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 5 times:
      | Complete |
    Then the output should not contain:
      |ruby-hello-world-1|
    """
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-7 |
      | build_name | ruby-hello-world-8 |
      | build_name | ruby-hello-world-9 |
    Then the step should succeed
    Given I run the :patch client command with:
      | resource      | bc                                                                                |
      | resource_name | ruby-hello-world                                                                  |
      | p             | {"spec":{"source":{"git":{"uri":"https://xxxgithub.com/sclorg/ruby-ex.git"}}}} |
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-12" build fails
    Then I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 2 times:
      | Git.*Cancelled |
    Then the output should match 3 times:
      | Git.*Failed |
    Then the output should not contain:
      |ruby-hello-world-7|
    """

