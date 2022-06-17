Feature: build 'apps' with CLI

  # @author cryan@redhat.com
  # @case_id OCP-11132
  Scenario: OCP-11132 Create a build config based on the provided image and source code
    Given I have a project
    When I run the :new_build client command with:
      | code         | https://github.com/openshift/ruby-hello-world |
      | image        | openshift/ruby                                |
      | l            | app=rubytest                                  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | URL:\\s+https://github.com/openshift/ruby-hello-world|
    Given the pod named "ruby-hello-world-1-build" becomes ready
    When I get project builds
    Then the output should contain:
      | NAME                |
      | ruby-hello-world-1  |
    When I get project is
    Then the output should contain:
      | ruby-hello-world |
    When I run the :new_build client command with:
      | app_repo |  openshift/ruby:2.0~https://github.com/openshift/ruby-hello-world.git |
      | strategy | docker                                                                |
      | name     | n1                                                                    |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | URL:\\s+https://github.com/openshift/ruby-hello-world|
    Given the pod named "n1-1-build" becomes ready
    When I get project builds
    Then the output should contain:
      | NAME                |
      | n1-1 |
    When I get project is
    Then the output should contain:
      | ruby-hello-world |

  # @author pruan@redhat.com
  Scenario Outline: when delete the bc,the builds pending or running should be deleted
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc<number>/test-buildconfig.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build becomes <build_status>
    Then I run the :delete client command with:
      | object_type | buildConfig |
      | object_name_or_id | ruby-sample-build |
    Then the step should succeed
    And I get project buildConfig
    Then the output should not contain:
      | ruby-sample-build |
    And I get project build
    Then the output should not contain:
      | ruby-sample-build |

    Examples:
      | number | build_status |
      | 517369 | :pending     | # @case_id OCP-11770
      | 517370 | :running     | # @case_id OCP-11942
      | 517367 | :complete    | # @case_id OCP-11224
      | 517368 | :failed      | # @case_id OCP-11550

  # @author xiuwang@redhat.com
  # @case_id OCP-11133
  Scenario: OCP-11133 Create a build config based on the source code in the current git repository
    Given I have a project
    And I git clone the repo "https://github.com/openshift/ruby-hello-world.git"
    When I run the :new_build client command with:
      | image | openshift/ruby   |
      | code  | ruby-hello-world |
      | e     | FOO=bar          |
      | name  | myruby           |
    Then the step should succeed
    And the "myruby-1" build was created
    And the "myruby-1" build completed
    When I run the :get client command with:
      | resource          | buildConfig |
      | resource_name     | myruby      |
      | o                 | yaml        |
    Then the output should match:
      | uri:\\s+https://github.com/openshift/ruby-hello-world |
      | name:\\s+FOO  |
      | value:\\s+bar |
    When I run the :get client command with:
      | resource          | imagestream |
      | resource_name     | myruby      |
      | o                 | yaml        |
    Then the output should match:
      | tag:\\s+latest |

    When I run the :new_build client command with:
      | code     | ruby-hello-world |
      | strategy | source           |
      | e        | key1=value1      |
      | e        | key2=value2      |
      | e        | key3=value3      |
      | name     | myruby1          |
    Then the step should succeed
    And the "myruby1-1" build was created
    And the "myruby1-1" build completed
    When I run the :get client command with:
      | resource          | buildConfig |
      | resource_name     | myruby1     |
      | o                 | yaml        |
    Then the output should match:
      | sourceStrategy:  |
      | name:\\s+key1    |
      | value:\\s+value1 |
      | name:\\s+key2    |
      | value:\\s+value2 |
      | name:\\s+key3    |
      | value:\\s+value3 |
      | type:\\s+Source  |

    When I run the :new_build client command with:
      | code  | ruby-hello-world |
      | e     | @#@=value        |
      | name  | myruby2          |
    Then the step should fail
    And the output should contain:
      |error:|
      |@#@=value|

  # @author xiuwang@redhat.com
  # @case_id OCP-11139
  Scenario: OCP-11139 Create applications only with multiple db images
    Given I create a new project
    When I run the :new_app client command with:
      | image_stream      | openshift/mongodb:2.6                               |
      | image_stream      | openshift/mysql                                     |
      | docker_image      | registry.access.redhat.com/rhscl/postgresql-94-rhel7|
      | env               | MONGODB_USER=test                                   |
      | env               | MONGODB_PASSWORD=test                               |
      | env               | MONGODB_DATABASE=test                               |
      | env               | MONGODB_ADMIN_PASSWORD=test                         |
      | env               | POSTGRESQL_USER=user                                |
      | env               | POSTGRESQL_DATABASE=db                              |
      | env               | POSTGRESQL_PASSWORD=test                            |
      | env               | MYSQL_ROOT_PASSWORD=test                            |
      | l                 | app=testapps                                        |
      | insecure_registry | true                                                |
    Then the step should succeed

    Given I wait for the "mysql" service to become ready up to 300 seconds
    And I get the service pods
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash | -c | mysql  -h $MYSQL_SERVICE_HOST -u root -ptest -e "show databases" |
    Then the step should succeed
    """
    And the output should contain "mysql"
    Given I wait for the "mongodb" service to become ready up to 300 seconds
    And I get the service pods
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | scl | enable | rh-mongodb26 | mongo $MONGODB_DATABASE -u $MONGODB_USER -p $MONGODB_PASSWORD  --eval 'db.version()' |
    Then the step should succeed
    """
    And the output should contain:
      | 2.6 |
    Given I wait for the "postgresql-94-rhel7" service to become ready up to 300 seconds
    And I get the service pods
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c |
      | psql -U user -c 'CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));' db |
    Then the step should succeed
    """
    And the output should contain:
      | CREATE TABLE |

  # @author cryan@redhat.com
  # @case_id OCP-11227
  Scenario: OCP-11227 Add multiple source inputs
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517667/ruby22rhel7-template-sti.json |
    Given the "ruby22-sample-build-1" build completes
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | yaml |
    Then the output should match "xiuwangs2i-2$"
    And the output should not match "xiuwangs2i$"
    Given 1 pods become ready with labels:
      | deploymentconfig=frontend |
    When I execute on the pod:
      | ls | xiuwangs2i |
    Then the step should fail
    When I execute on the pod:
      | ls |
    Then the step should succeed
    And the output should contain:
      | xiuwangs2i-2 |

  # @case_id OCP-10771
  Scenario: OCP-10771 Add a image with multiple paths as source input
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517666/ruby22rhel7-template-sti.json |
    Given the "ruby22-sample-build-1" build completes
    When I get project build_config named "ruby22-sample-build" as YAML
    Then the output should contain "xiuwangs2i-2"
    Given 1 pods become ready with labels:
      | deploymentconfig=frontend |
    When I execute on the pod:
      | ls | -al | xiuwangs2i-2 |
    Then the step should succeed
    And the output should contain "tmp"

  # @author cryan@redhat.com
  # @case_id OCP-11943
  Scenario: OCP-11943 Using a docker image as source input using new-build cmd
    Given I have a project
    When I run the :tag client command with:
      | source | openshift/python:latest |
      | dest   | python:latest |
    Then the step should succeed
    And the "python" image stream becomes ready
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | <%= project.name %>/python:latest |
      | source_image_path | /tmp:xiuwangtest/ |
      | name | final-app |
      | allow_missing_imagestream_tags| true |
    Then the step should succeed
    When I get project build_config named "final-app" as YAML
    Then the output should match:
      | kind:\s+ImageStreamTag |
      | name:\s+python:latest |
      | destinationDir:\s+xiuwangtest |
      | sourcePath:\s+/tmp |
    Given the "final-app-1" build completes
    Given I get project builds
    #Create a deploymentconfig to generate pods to test on,
    #Avoids the use of direct docker commands.
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517670/dc.json"
    Then the step should succeed
    Given I replace lines in "dc.json":
      | replaceme | final-app |
    Given I replace lines in "dc.json":
      | origin-ruby22-sample | final-app |
    When I run the :create client command with:
      | f | dc.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=frontend |
    When I execute on the pod:
      | ls | -al | xiuwangtest/tmp |
    Then the step should succeed
    Given I replace resource "buildconfig" named "final-app" saving edit to "edit_bldcfg.json":
      | destinationDir: xiuwangtest/ | destinationDir: test/ |
    When I run the :start_build client command with:
      | buildconfig | final-app |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=frontend-2 |
    When I execute on the pod:
      | ls | -al | test |
    Then the output should contain "tmp"
    Then I run the :import_image client command with:
      | image_name | python |
      | all | true |
      | confirm | true |
      | from | docker.io/openshift/python-33-centos7 |
      | n | <%= project.name %> |
    Then the step should succeed
    Given I get project builds
    Then the output should contain "final-app-3"

  # @author cryan@redhat.com
  # @case_id OCP-11776
  Scenario: OCP-11776 Cannot create secret from local file and with same name via oc new-build
    Given I have a project
    #Reusing similar secrets to TC #519256
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret1.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret2.json |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | ruby:2.2 |
      | app_repo | https://github.com/openshift-qe/build-secret.git |
      | build_secret | /local/src/file:/destination/dir |
    Then the step should fail
    And the output should contain "must be valid secret"
    When I run the :new_build client command with:
      | image_stream | ruby:2.2 |
      | app_repo | https://github.com/openshift-qe/build-secret.git |
      | strategy | docker |
      | build_secret | testsecret1:/tmp/mysecret |
      | build_secret | testsecret2 |
    Then the step should fail
    And the output should contain "must be a relative path"

  # @author xiuwang@redhat.com
  # @case_id OCP-11552
  Scenario: OCP-11552 Using a docker image as source input for docker build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517668/ruby22rhel7-template-docker.json |
    Given the "ruby22-sample-build-1" build completes
    When I get project build_config named "ruby22-sample-build" as YAML
    Then the output should contain "xiuwangtest"
    Given 2 pods become ready with labels:
      | deployment=frontend-1 |
    When I execute on the pod:
      | ls | -al | xiuwangtest/tmp |
    Then the step should succeed

  # @author yantan@redhat.com
  Scenario Outline: Do sti/custom build with no inputs in buildconfig
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/nosrc-extended-test-bldr/master/nosrc-setup.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/nosrc-extended-test-bldr/master/nosrc-test.json  |
    When I get project bc
    Then the output should contain:
      | <bc_name> |
    When I run the :start_build client command with:
      | buildconfig | nosrc-bldr |
    Then the step should succeed
    Given the "nosrc-bldr-1" build becomes :complete
    When I run the :start_build client command with:
      | buildconfig | <bc_name> |
    Given the "<build_name>" build becomes :complete
    When I run the :delete client command with:
      | object_type       | bc         |
      | object_name_or_id |  <bc_name> |
    Then the step should succeed
    When I run the :create client command with:
      | f | <file_name> |
    When I get project build_config named "<bc_name>"
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig   | <bc_name> |
    Then the step should succeed
    Given the "<build_name>" build becomes :complete

    Examples:
      | bc_name              | build_name             | file_name                                                                                             |
      | ruby-sample-build-ns | ruby-sample-build-ns-1 | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc525736/Nonesrc-sti.json    | # @case_id OCP-11580
      | ruby-sample-build-nc | ruby-sample-build-nc-1 | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc525735/Nonesrc-docker.json | # @case_id OCP-11268

  # @author cryan@redhat.com
  # @case_id OCP-11582
  Scenario: OCP-11582 Change runpolicy to SerialLatestOnly build
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json"
    And I replace lines in "ruby22rhel7-template-sti.json":
      | registry.access.redhat.com | <%= product_docker_repo %> |
    And I process and create "ruby22rhel7-template-sti.json"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    Given the "ruby22-sample-build-1" build becomes :running
    And I get project builds
    Then the output should contain 1 times:
      | Running |
    And the output should contain 3 times:
      | New     |
    When I run the :patch client command with:
      | resource      | buildconfig                                  |
      | resource_name | ruby22-sample-build                          |
      | p             | {"spec": {"runPolicy" : "SerialLatestOnly"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    Given the "ruby22-sample-build-1" build completes
    And the "ruby22-sample-build-6" build becomes :running
    And I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And the output should match 4 times:
      | Git.*Cancelled |
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    And the "ruby22-sample-build-7" build becomes :cancelled
    Given I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And the output should match 5 times:
      | Git.*Cancelled |
    And the output should contain 1 times:
      | New       |
    When I run the :patch client command with:
      | resource      | buildconfig                        |
      | resource_name | ruby22-sample-build                |
      | p             | {"spec": {"runPolicy" : "Serial"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    Given I get project builds
    Then the output should contain 1 times:
      | Complete  |
    And the output should contain 1 times:
      | Running   |
    And the output should match 5 times:
      | Git.*Cancelled |
    And the output should contain 3 times:
      | New       |

  # @author cryan@redhat.com
  Scenario Outline: Cancel multiple new/pending/running builds
    Given I have a project
    When I run the :new_build client command with:
      | image    | openshift/ruby:latest                            |
      | app_repo | http://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    Given I run the steps 5 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given I get project builds
    Then the output should contain 6 times:
      | ruby-hello-world- |
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-1 |
      | build_name | ruby-hello-world-2 |
    Then the step should succeed
    Given I get project builds
    Then the output should match 2 times:
      | Git.*Cancelled |
    #This prevents a timing issue with the 4th build not being cancelled/started:
    Given the "ruby-hello-world-4" build becomes :pending
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
      | state   | new                 |
    Then the step should succeed
    Given I get project builds
    Then the output should match 4 times:
      | Git.*Cancelled |
    And the output should not contain "New"
    #This prevents a timing issue with the 4th build as above:
    Given the "ruby-hello-world-4" build completes
    When I run the :patch client command with:
      | resource      | buildconfig                              |
      | resource_name | ruby-hello-world                         |
      | p             | {"spec": {"runPolicy": "Parallel"}} |
    Then the step should succeed
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-9" build becomes :pending
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-7 |
      | build_name | ruby-hello-world-8 |
      | build_name | ruby-hello-world-9 |
    Then the step should succeed
    And I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match <num1> times:
      | Git.*Cancelled |
    """
    And the output should not contain "New"
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
      | state   | pending             |
    Then the step should succeed
    And I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match <num2> times:
      | Git.*Cancelled |
    """
    And the output should not contain "New"
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given I get project builds
    Given the "ruby-hello-world-13" build becomes :running
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-13 |
      | build_name | ruby-hello-world-14 |
      | build_name | ruby-hello-world-15 |
    Then the step should succeed
    And I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match <num3> times:
      | Git.*Cancelled |
    """
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    Given the "ruby-hello-world-16" build becomes :running
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
      | state   | running             |
    Then the step should succeed
    And I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match <num4> times:
      | Git.*Cancelled |
    """
    Given I run the steps 3 times:
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    """
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
    Then the step should succeed
    And I wait up to 480 seconds for the steps to pass:
    """
    Given I get project builds
    Then the output should match <num5> times:
      | Git.*Cancelled |
    """

    Examples:
      | num1 | num2 | num3 | num4 | num5 |
      | 7    | 10   | 13   | 16   | 19   | # @case_id OCP-11272
      | 5    | 5    | 5    | 5    | 5    | # @case_id OCP-15019

  # @author haowang@redhat.com
  Scenario Outline: The default runpolicy is Serial build -- new-build/new-app command
    Given I have a project
    When I run the :<cmd> client command with:
      | app_repo | openshift/ruby:latest~http://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-1" build becomes :running
    And the "ruby-hello-world-2" build was created
    And the "ruby-hello-world-2" build becomes :new
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-3" build was created
    And the "ruby-hello-world-3" build becomes :new
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-4" build was created
    And the "ruby-hello-world-4" build becomes :new
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-5" build was created
    And the "ruby-hello-world-5" build becomes :new
    When I run the :cancel_build client command with:
      | build_name | ruby-hello-world-2 |
    Then the step should succeed
    And the "ruby-hello-world-2" build becomes :cancelled
    Given the "ruby-hello-world-1" build completes
    And the "ruby-hello-world-3" build becomes :running
    And the "ruby-hello-world-4" build is :new
    And the "ruby-hello-world-5" build is :new
    When I run the :cancel_build client command with:
      | bc_name | bc/ruby-hello-world |
      | state   | new                 |
    Then the step should succeed
    And the "ruby-hello-world-4" build was cancelled
    And the "ruby-hello-world-5" build was cancelled
    And the "ruby-hello-world-3" build is :running
    Given I run the :patch client command with:
      | resource      | bc                                                                                |
      | resource_name | ruby-hello-world                                                                  |
      | p             | {"spec":{"source":{"git":{"uri":"https://xxxgithub.com/sclorg/ruby-ex.git"}}}} |
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-6" build was created
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-7" build was created
    Given the "ruby-hello-world-3" build completes
    Then the "ruby-hello-world-6" build becomes :failed
    Then the "ruby-hello-world-7" build becomes :failed

    Examples:
      | cmd       |
      | new_build | # @case_id OCP-12066
      | new_app   | # @case_id OCP-11954

  # @author pruan@redhat.com
  # @case_id OCP-10944
  Scenario: OCP-10944 Simple error message return when no value followed with oc build-logs
    Given I have a project
    When I run the :build_logs client command with:
      | build_name | |
    Then the step should fail
    And the output should contain:
      | resource name may not be empty |
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build becomes :running
    When I run the :build_logs client command with:
      | build_name | |
    Then the step should fail
    And the output should contain:
      | resource name may not be empty |
    When I run the :build_logs client command with:
      | build_name |  |
      | n             | default |
    Then the step should fail
    And the output should contain:
      | resource name may not be empty |

  # @author cryan@redhat.com
  # @case_id OCP-11023
  Scenario: OCP-11023 Handle build naming collisions
    Given I have a project
    When I run the :new_build client command with:
      | app_repo     | https://github.com/openshift/ruby-hello-world.git |
      | image_stream | ruby:latest                                       |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc539699/build.yaml | 
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should fail
    And the output should contain:
      | already exists |
      | Retry building |
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    Given the "ruby-hello-world-3" build was created

  # @author xiuwang@redhat.com
  # @case_id OCP-10942
  Scenario: OCP-10942 Build env vars are set correctly for Extended build
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/test-for-s2i-extendbuild/master/extended-bc-scripts-in-repo.json |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | extended-build-from-repo |
    Then the step should succeed
    And the "extended-build-from-repo-1" build completed
    Then evaluation of `image_stream("extended-repo").docker_image_repository(user: user)` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    And I execute on the pod:
      | env |
    Then the output should contain:
      | S2I_TEST_FOO=bar |

  # @author wzheng@redhat.com
  # @case_id OCP-17523
  Scenario: OCP-17523 io.openshift.build.commit.ref displays correctly in build reference on imagestreamtag if building from git branch reference
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world#beta4 |
    Then the step should succeed
    Given the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build completed
    When I run the :describe client command with:
      | resource | imagestreamtag |
    Then the output should contain:
      | io.openshift.build.commit.ref=beta4 |
      | OPENSHIFT_BUILD_REFERENCE=beta4     | 

  # @author xiuwang@redhat.com
  # @case_id OCP-19631
  Scenario: OCP-19631 Insert configmap when create a buildconfig
    Given I have a project
    Given a "configmap.test" file is created with the following lines:
    """
    color.good=purple
    color.bad=yellow
    """
    When I run the :create_configmap client command with:
      | name      | cmtest         |
      | from_file | configmap.test |
    Then the step should succeed
    When I run the :create_secret client command with:
      | name         | secrettest      |
      | secret_type  | generic         |
      | from_literal | aoskey=aosvalue |
    Then the step should succeed
    #Insert cm and secret to bc with default destination
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | image_stream   | ruby                                          |
      | build_config_map| cmtest                                       |
      | build_secret   | secrettest                                    |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:\s+cmtest->. |
      | Build Secrets:\s+secrettest->.|
    And the "ruby-hello-world-1" build completed
    Then evaluation of `image_stream("ruby-hello-world").docker_image_repository` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    When I execute on the pod:
      | ls | -l |
    Then the step should succeed
    And the output should contain:
      | configmap.test -> ..data/configmap.test |
      | aoskey -> ..data/aoskey                 | 
    When I execute on the pod:
      | cat | configmap.test |
    Then the step should succeed
    And the output should contain:
      | color.good=purple |
      | color.bad=yellow  |
    When I execute on the pod:
      | cat | aoskey |
    Then the step should succeed
    And the output should not contain:
      | aosvalue |
    Then I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    #Insert cm and secret to bc with specified destination
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | image_stream   | ruby                                          |
      | build_config_map| cmtest:.m2                                   |
      | build_secret   | secrettest:.ssh                               |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:\s+cmtest->.m2  |
      | Build Secrets:\s+secrettest->.ssh|
    And the "ruby-hello-world-1" build completed
    Then evaluation of `image_stream("ruby-hello-world").docker_image_repository` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    When I execute on the pod:
      | ls | -al | .ssh | .m2 |
    Then the step should succeed
    And the output should contain:
      | configmap.test -> ..data/configmap.test |
      | aoskey -> ..data/aoskey                 | 
    Then I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    #Insert cm and secret to bc with empty destination - succeed
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | image_stream   | ruby                                          |
      | build_config_map| cmtest:                                      |
      | build_secret   | secrettest:                                   |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:\s+cmtest->.    |
      | Build Secrets:\s+secrettest->.|
    Then I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    #Insert cm and secret to bc with abs path - succeed
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | image_stream   | ruby                                          |
      | build_config_map| cmtest:/aoscm                                |
      | build_secret   | secrettest:/aossecret                         |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:	cmtest->/aoscm        |
      | Build Secrets:		secrettest->/aossecret|
    Given the "ruby-hello-world-1" build completed
    Then evaluation of `image_stream("ruby-hello-world").docker_image_repository` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    When I execute on the pod:
      | ls | -al | /aoscm/ | /aossecret/|
    Then the step should succeed
    And the output should contain:
      | configmap.test -> ..data/configmap.test |
      | aoskey -> ..data/aoskey                 | 

  # @author xiuwang@redhat.com
  # @case_id OCP-18962
  Scenario: OCP-18962 Allow using a configmap as an input to a docker build
    Given I have a project
    Given a "configmap1.test" file is created with the following lines:
    """
    color.good=purple
    color.bad=yellow
    """
    Given a "configmap2.test" file is created with the following lines:
    """
    color.good=brightyellow
    color.bad=black
    """
    When I run the :create_configmap client command with:
      | name      | cmtest1         |
      | from_file | configmap1.test |
    Then the step should succeed
    When I run the :create_configmap client command with:
      | name      | cmtest2         |
      | from_file | configmap2.test |
    Then the step should succeed
    #Insert cm and secret to bc with empty destination - succeed
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | build_config_map| cmtest1:.                                    |
      | build_config_map| cmtest2:./newdir                             |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:\s+cmtest1->.,cmtest2->newdir | 
    And the "ruby-hello-world-1" build completed
    Then evaluation of `image_stream("ruby-hello-world").docker_image_repository` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    When I execute on the pod:
      | ls | -l |
    And the output should match:
      | -rw-------.*configmap1.test |
    When I execute on the pod:
      | ls | -l | newdir |
    And the output should contain:
      | configmap2.test |
    Then I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    #Add a configmaps with a multi-level dirs - succeed
    When I run the :new_build client command with:
      | app_repo       | https://github.com/openshift/ruby-hello-world |
      | build_config_map| cmtest1:./newdir1/newdir2/newdir3            |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | Build ConfigMaps:\s+cmtest1->newdir1/newdir2/newdir3 | 
    And the "ruby-hello-world-1" build completed
    Then evaluation of `image_stream("ruby-hello-world").docker_image_repository` is stored in the :user_image clipboard
    When I run the :run client command with:
      | name  | myapp                |
      | image | <%= cb.user_image %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myapp-1 |
    When I execute on the pod:
      | ls | -l | newdir1/newdir2/newdir3|
    And the output should match:
      | -rw-------.*configmap1.test |

