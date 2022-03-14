Feature: buildlogic.feature

  # @author haowang@redhat.com
  # @case_id OCP-11545
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Build with specified Dockerfile via new-build -D
    Given I have a project
    When I run the :new_build client command with:
      | D    | FROM quay.io/openshifttest/base-alpine@sha256:0b379877aba876774e0043ea5ba41b0c574825ab910d32b43c05926fab4eea22\nRUN echo "hello" |
      | to   | myappis |
      | name | myapp   |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed

  # @author xiazhao@redhat.com
  # @case_id OCP-11170
  Scenario: Result image will be tried to push after multi-build
    Given I have a project
    Given I obtain test data file "image/language-image-templates/php-55-rhel7-stibuild.json"
    When I run the :new_app client command with:
      | file |  php-55-rhel7-stibuild.json |
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
  Scenario: Create build without output
    Given I have a project
    When I run the :new_build client command with:
      | app_repo  | openshift/ruby~https://github.com/openshift/ruby-hello-world.git |
      | no-output | true                                                             |
      | name      | myapp                                                            |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed

  # @author yantan@redhat.com
  # @case_id OCP-10799
  @proxy
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Create new build config use dockerfile with source repo
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world   |
      | D        | FROM quay.io/openshifttest/ruby-27:multiarch\nRUN echo ok |
    Then the step should succeed
    When I get project buildconfigs as YAML
    Then the step should succeed
    Then the output should match:
      | dockerfile   |
      | FROM quay.io/openshifttest/ruby-27:multiarch   |
      | RUN echo ok  |
      | uri: https://github.com/openshift/ruby-hello-world |
      | type: [Gg]it |
    When I get project build
    Then the "ruby-hello-world-1" build completed

  # @author haowang@redhat.com
  @4.10 @4.9 @4.8 @4.7
  Scenario Outline: ForcePull image for build
    Given I have a project
    Given I obtain test data file "build/forcePull/<template>"
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

    @proxy
    @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
    @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
    Examples:
      | template                            |
      | buildconfig-docker-ImageStream.json | # @case_id OCP-10651
      | buildconfig-s2i-ImageStream.json    | # @case_id OCP-11148
      | buildconfig-docker-dockerimage.json | # @case_id OCP-10652

    @upgrade-sanity
    @singlenode
    @connected
    Examples:
      | template                            |
      | buildconfig-s2i-dockerimage.json    | # @case_id OCP-11149

  # @author yantan@redhat.com
  # @case_id OCP-10745
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Build with specified Dockerfile to image with same image name via new-build
    Given I have a project
    When I run the :new_build client command with:
      | D  | FROM quay.io/openshifttest/centos@sha256:285bc3161133ec01d8ca8680cd746eecbfdbc1faa6313bd863151c4b26d7e5a5 |
      | to | centos |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc     |
      | name     | centos |
    Then the output should match:
      | From Image:\s+ImageStreamTag centos:latest |
      | Output to:\s+ImageStreamTag centos:latest  |
    Given the "centos-1" build becomes :complete
    When I run the :new_build client command with:
      | D    | FROM quay.io/openshifttest/centos@sha256:285bc3161133ec01d8ca8680cd746eecbfdbc1faa6313bd863151c4b26d7e5a5 |
      | to   | centos:7 |
      | name | myapp    |
    And I get project bc
    Then the output should contain:
      | myapp |
    Given the "myapp-1" build becomes :complete
    And the "myapp-2" build becomes :complete
    And the "myapp-3" build becomes :running
    When I run the :new_build client command with:
      | code         | https://github.com/sclorg/nodejs-ex.git       |
      | image_stream | openshift/nodejs:0.10                         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby:2.0                            |
      | to           | centos:7                                      |
    Then the step should fail
    And the output should contain:
      | error |

  # @author haowang@redhat.com
  # @case_id OCP-11720
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  Scenario: Build from private git repo with/without ssh key
    Given I have a project
    And I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :create_secret client command with:
      | secret_type | generic               |
      | name        | mysecret              |
      | from_file   | ssh-privatekey=secret |
    Then the step should succeed
    When I execute on the pod:
      | bash |
      | -c   |
      | cd /repos/ && rm -rf sample.git && git clone --bare https://github.com/openshift/ruby-hello-world sample.git |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | openshift/ruby                                |
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
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  Scenario: Create new-app from private git repo with ssh key
    Given I have a project
    When I run the :new_app client command with:
      | image_stream   | openshift/perl:latest                            |
      | code           | https://github.com/sclorg/s2i-perl-container.git |
      | context_dir    | 5.30/test/sample-test-app/                       |
    Then the step should succeed
    Given the "s2i-perl-container-1" build completes
    And I have an ssh-git service in the project
    And the "secret" file is created with the following lines:
      | <%= cb.ssh_private_key.to_pem %> |
    And I run the :create_secret client command with:
      | secret_type | generic               |
      | name        | mysecret              |
      | from_file   | ssh-privatekey=secret |
    Then the step should succeed
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
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Check s2i build substatus and times
    Given I have a project
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | file | application-template-stibuild.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Duration:\s+(\d+m)?\d+s        |
      | FetchInputs:\s+(\d+m)?\d+s     |
      | PushImage:\s+(\d+m)?\d+s       |

  # @author dyan@redhat.com
  # @case_id OCP-13684
  @flaky
  @proxy
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @connected
  Scenario: Check docker build substatus and times
    Given I have a project
    Given I obtain test data file "build/application-template-dockerbuild.json"
    When I run the :new_app client command with:
      | file | application-template-dockerbuild.json |
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
      | PushImage:\s+(\d+m)?\d+s   |

  # @author xiuwang@redhat.com
  # @case_id OCP-13914
  Scenario: Prune old builds automaticly
    #Should prune completed builds based on the successfulBuildsHistoryLimit setting
    Given I have a project
    When I run the :new_build client command with:
      | D    | FROM busybox\nRUN touch /php-file |
      | name | myphp                             |
    Then the step should succeed
    Given the "myphp-1" build completed
    Given I run the steps 6 times:
    """
    When I run the :start_build client command with:
      | buildconfig | myphp |
    Then the step should succeed
    """
    Given the "myphp-7" build completed
    Then I wait up to 120 seconds for the steps to pass:
    """
    When I save project builds into the :builds_all clipboard
    And evaluation of `cb.builds_all.select{|b| b.status?(user: user, status: :complete)[:success]}.size` is stored in the :builds_nums clipboard
    Then the expression should be true> cb.builds_nums >= 5 && cb.builds_nums < 7
    """
    Given I get project builds
    Then the output should not contain:
      | myphp-1 |

  # @author xiuwang@redhat.com
  # @case_id OCP-24154
  Scenario: Should prune canceled builds based on the failedBuildsHistoryLimit setting
    Given I have a project
    When I run the :new_app client command with:
      | template | rails-postgresql-example |
    Then the step should succeed
    Given I run the :patch client command with:
      | resource      | bc                                       |
      | resource_name | rails-postgresql-example                 |
      | p             | {"spec":{"failedBuildsHistoryLimit": 2}} |
    Then the step should succeed
    When I run the :cancel_build client command with:
      | build_name | rails-postgresql-example-1 |
    Then the step should succeed
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | rails-postgresql-example |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | bc_name | bc/rails-postgresql-example |
    Then the step should succeed
    Then I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 2 times:
      | Git.*Cancelled |
    Then the output should not contain:
      | rails-postgresql-example-1 |
    """

  # @author xiuwang@redhat.com
  # @case_id OCP-24155
  Scenario: Should prune failed builds based on the failedBuildsHistoryLimit setting
    Given I have a project
    When I run the :new_app client command with:
      | template | rails-postgresql-example                                         |
      | p        | SOURCE_REPOSITORY_URL=https://github.com/sclorg/unexist-repo.git |
    Then the step should succeed
    Given I run the steps 6 times:
    """
    When I run the :start_build client command with:
      | buildconfig | rails-postgresql-example |
    Then the step should succeed
    """
    Given the "rails-postgresql-example-7" build becomes :failed
    Then I wait up to 120 seconds for the steps to pass:
    """
    When I save project builds into the :builds_all clipboard
    And evaluation of `cb.builds_all.select{|b| b.status?(user: user, status: :failed)[:success]}.size` is stored in the :builds_nums clipboard
    Then the expression should be true> cb.builds_nums >= 5 && cb.builds_nums < 7
    """
    Given I get project builds
    Then the output should not contain:
      | rails-postgresql-example-1 |

  # @author xiuwang@redhat.com
  # @case_id OCP-24156
  Scenario: Should prune errored builds based on the failedBuildsHistoryLimit setting
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/test/extended/testdata/builds/build-pruning/errored-build-config.yaml |
    Then the step should succeed
    Given I run the steps 4 times:
    """
    When I run the :start_build client command with:
      | buildconfig | myphp |
    Then the step should succeed
    """
    Then I wait up to 120 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 2 times:
      | Git.*Error |
    Then the output should not contain:
      | myphp-1 |
    """

  # @author xiuwang@redhat.com
  # @case_id OCP-24158
  Scenario: Should prune builds after a buildConfig change
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | ruby                                              |
      | code         | https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-1 |
    Then the step should succeed
    Given I run the steps 6 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
    Then the step should succeed
    Then I wait up to 120 seconds for the steps to pass:
    """
    When I save project builds into the :builds_all clipboard
    And evaluation of `cb.builds_all.select{|b| b.status?(user: user, status: :cancelled)[:success]}.size` is stored in the :builds_nums clipboard
    Then the expression should be true> cb.builds_nums >= 5 && cb.builds_nums < 7
    """
    Given I get project builds
    Then the output should not contain:
      |ruby-hello-world-1|
    Given I run the :patch client command with:
      | resource      | bc                                       |
      | resource_name | ruby-hello-world                         |
      | p             | {"spec":{"failedBuildsHistoryLimit": 2}} |
    Then the step should succeed
    Then I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 2 times:
      | Git.*Cancelled |
    Then the output should not contain:
      | ruby-hello-world-2 |
      | ruby-hello-world-3 |
      | ruby-hello-world-4 |
    """

  # @author xiuwang@redhat.com
  # @case_id OCP-24159
  Scenario: Buildconfigs should have a default history limit set when created via the group api
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig      |
      | name     | ruby-hello-world |
    Then the step should succeed
    Then the output should contain:
      | Builds History Limit |
      | Successful:	5        |
      | Failed:		5          |

  # @author xiuwang@redhat.com
  # @case_id OCP-19133
  @proxy
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  Scenario: Pipeline build can be pruned automatically
    Given I have a project
    And I have a jenkins v2 application
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/pipeline/samplepipeline.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig     |
      | name     | sample-pipeline |
    Then the step should succeed
    Then the output should contain:
      | Builds History Limit |
      | Successful:	5        |
      | Failed:		5          |
    Given I run the :patch client command with:
      | resource      | bc                                                                         |
      | resource_name | sample-pipeline                                                            |
      | p             | {"spec":{"failedBuildsHistoryLimit": 1,"successfulBuildsHistoryLimit": 1}} |
    Then the step should succeed
    Given I run the steps 2 times:
    """
    When I run the :start_build client command with:
      | buildconfig | sample-pipeline |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | build_name | sample-pipeline-2 |
    Then the step should succeed
    Given the "sample-pipeline-1" build completed
    Given I run the steps 2 times:
    """
    When I run the :start_build client command with:
      | buildconfig | sample-pipeline |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | build_name | sample-pipeline-4 |
    Then the step should succeed
    Given the "sample-pipeline-3" build completed
    And I wait up to 120 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match 1 times:
      | sample-pipeline.*Cancelled |
      | sample-pipeline.*Complete  |
    """

  # @author xiuwang@redhat.com
  # @case_id OCP-40366
  @admin
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  Scenario: Mirroring built image doesn't degrade scheme2 ,keep consistent SHA's
    Given I have a project
    Given I save a htpasswd registry auth to the :combine_dockercfg clipboard
    And default image registry route is stored in the :integrated_reg_host clipboard
    And I have a skopeo pod in the project
    And master CA is added to the "skopeo" dc
    When I run the :new_app client command with:
      | app_repo | httpd:latest~https://github.com/sclorg/httpd-ex.git |
    Then the step should succeed
    Given the "httpd-ex-1" build completed
    When I execute on the pod:
      | skopeo                                                                     |
      | inspect                                                                    |
      | --tls-verify=false                                                         |
      | --creds                                                                    |
      | <%= user.name %>:<%= user.cached_tokens.first %>                           |
      | --raw                                                                      |
      | docker://<%= cb.integrated_reg_host %>/<%= project.name %>/httpd-ex:latest |
    Then the step should succeed
    Then the output should match:
      | "schemaVersion":2 |
    Then I run the :image_mirror client command with:
      | source_image | <%= cb.integrated_reg_host %>/<%= project.name %>/httpd-ex:latest |
      | dest_image   | <%= cb.custom_registry %>/myimage:latest                          |
      | a            | <%= cb.combine_dockercfg %>                                       |
      | insecure     | true                                                              |
    And the step should succeed
    When I execute on the pod:
      | skopeo                                            |
      | inspect                                           |
      | --tls-verify=false                                |
      | --creds                                           |
      | <%= cb.reg_user %>:<%= cb.reg_pass %>             |
      | --raw                                             |
      | docker://<%= cb.custom_registry %>/myimage:latest |
    Then the step should succeed
    Then the output should match:
      | "schemaVersion":2 |
