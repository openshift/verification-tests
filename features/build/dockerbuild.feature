Feature: dockerbuild.feature

  # @author wzheng@redhat.com
  # @case_id OCP-11078
  Scenario: Docker build with blank source repo
    Given I have a project
    When I run the :process client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker-blankrepo.json |
    Then the step should succeed
    Given I save the output to file>blankrepo.json
    When I run the :create client command with:
      | f | blankrepo.json |
    Then the step should fail
    Then the output should match "spec.source.git.uri: [Rr]equired value"

  # @author wzheng@redhat.com
  # @case_id OCP-12115
  @smoke
  Scenario: Docker build with both SourceURI and context dir
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-context-docker.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby20-sample-build-1" build was created
    And the "ruby20-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | buildconfig         |
      | name     | ruby20-sample-build |
    Then the step should succeed
    And the output should contain "ContextDir:"

  # @author dyan@redhat.com
  Scenario Outline: Docker and STI build with dockerImage with specified tag
    Given I have a project
    When I run oc create over "<template>" replacing paths:
      | ["spec"]["strategy"]["<strategy>"]["from"]["name"] | quay.io/openshifttest/ruby-25-centos7 | 
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the output should contain:
      | DockerImage quay.io/openshifttest/ruby-25-centos7 |
    When I run the :patch client command with:
      | resource      | bc                                                                                                       |
      | resource_name | ruby-sample-build                                                                                        |
      | p             | {"spec":{"strategy":{"<strategy>":{"from":{"name":"quay.io/openshifttest/ruby-25-centos7:incorrect"}}}}} |
    Then the step should succeed
    Given I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    And the "ruby-sample-build-2" build failed
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-2 |
    Then the output should contain:
      | Failed                                                      |
      | DockerImage quay.io/openshifttest/ruby-25-centos7:incorrect |

    Examples:
      | template | strategy |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json | dockerStrategy | # @case_id OCP-11109
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc482273/test-template-stibuild.json    | sourceStrategy | # @case_id OCP-11120

  # @author wewang@redhat.com
  # @case_id OCP-9869
  Scenario: Setting the nocache option in docker build strategy
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    And the "ruby22-sample-build-1" build completed
    When I run the :patch client command with:
      | resource      | bc                              |
      | resource_name | ruby22-sample-build             |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"noCache":true}}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig |
      | name     | ruby22-sample-build |
    Then the step should succeed
    Then the output should match "No Cache:\s+true"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    And the "ruby22-sample-build-2" build completed
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-2 |
    Then the step should succeed
    Then the output should not contain:
      | Using cache  |
    When I run the :patch client command with:
      | resource      | bc                              |
      | resource_name | ruby22-sample-build             |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"noCache":false}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    And the "ruby22-sample-build-3" build completed
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-3 |
      | loglevel   | 6                     |
    Then the step should succeed
    Then the output should contain:
      | Using cache |

  # @author dyan@redhat.com
  # @case_id OCP-13083
  Scenario: Docker build using Dockerfile with 'FROM scratch'
    Given I have a project
    When I run the :new_build client command with:
      | D  | FROM scratch\nENV NUM 1 |
      | to | test                    |
    Then the step should succeed
    When the "test-1" build completed
    And I run the :logs client command with:
      | resource_name | bc/test |
      | f             |         |
    Then the output should contain:
      | FROM scratch |
    And the output should not match:
      | [Ee]rror |

  # @author wzheng@redhat.com
  # @case_id OCP-12762
  Scenario: Docker build with invalid context dir
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-invalidcontext-docker.json |
    Then the step should succeed
    When the "ruby20-sample-build-1" build failed
    And I get project build
    And the output should contain:
      | InvalidContextDirectory |
    When I run the :describe client command with:
      | resource | build |
    Then the output should contain:
      | The supplied context directory does not exist |

  # @author dyan@redhat.com
  # @case_id OCP-12855
  Scenario: Add ARGs in docker build
    Given I have a project
    When I run the :new_build client command with:
      | code      | https://github.com/openshift/ruby-hello-world |
      | build_arg | ARG=VALUE                                     |
    Then the step should succeed
    Given the "ruby-hello-world-1" build was created
    When I run the :export client command with:
      | resource | build/ruby-hello-world-1 |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG    |
      | value:\\s+VALUE |
    # start build with build-arg
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | build_arg   | ARG1=VALUE1      |
    Then the step should succeed
    Given the "ruby-hello-world-2" build was created
    When I run the :export client command with:
      | resource | build/ruby-hello-world-2 |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG1    |
      | value:\\s+VALUE1 |
    When I run the :start_build client command with:
      | from_build | ruby-hello-world-1 |
      | build_arg  | ARG=NEWVALUE       |
    Then the step should succeed
    Given the "ruby-hello-world-3" build was created
    When I run the :export client command with:
      | resource | build/ruby-hello-world-3 |
    Then the step should succeed
    And the output should match:
      | name:\\s+ARG       |
      | value:\\s+NEWVALUE |

  # @author wewang@redhat.com
  # @case_id OCP-15461
  Scenario: Allow nocache to be specified on docker build request
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
      | no-cache    | true              |
    Then the step should succeed
    And the "ruby-sample-build-2" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build-2 |
    Then the output should not contain:
      | Using cache |
    When I run the :describe client command with:
      | resource    | build               |
      | name        | ruby-sample-build-2 |
    Then the step should succeed
    Then the output should match "No Cache:\s+true"
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
      | no-cache    | false             |
    Then the step should succeed
    And the "ruby-sample-build-3" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build-3 |
    Then the output should contain:
      | Using cache                               |

  # @author wewang@redhat.com
  # @case_id OCP-15462
  Scenario: Override nocache setting using --no-cache flag when docker build request
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    When I run the :patch client command with:
      | resource      | bc                                                        |
      | resource_name | ruby-sample-build                                         |
      | p             | {"spec":{"strategy":{"dockerStrategy":{"noCache":true}}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig                    |
      | name     | ruby-sample-build              |
    Then the step should succeed
    Then the output should match "No Cache:\s+true"
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build           |
      | no-cache    | false                       |
    Then the step should succeed
    And the "ruby-sample-build-2" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build-2 |
    Then the output should contain:
      | Using cache                               |

  # @author wzheng@redhat.com
  # @case_id OCP-18501
  Scenario: Support additional EXPOSE values in new-app
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift-qe/oc_newapp_expose |
    Then the step should succeed
    And the output should contain:
      | invalid ports in EXPOSE instruction |
      | Ports 8080/tcp, 8081/tcp, 8083/tcp, 8084/tcp, 8085/tcp, 8087/tcp, 8090/tcp, 8091/tcp, 8092/tcp, 8093/tcp, 8094/tcp, 8100/udp, 8101/udp |

