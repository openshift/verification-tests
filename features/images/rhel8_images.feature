Feature: rhel8images.feature

  # @author xiuwang@redhat.com
  # @case_id OCP-22950
  @admin
  @proxy
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Using new-app cmd to create app with ruby rhel8 image
    Given I have a project
    When I run the :tag admin command with:
      | source           | registry.redhat.io/rhel8/ruby-25:latest |
      | dest             | qe-ruby-25-rhel8:latest                 |
      | reference_policy | local                                   |
      | n                | openshift                               |
    Then the step should succeed
    When I run the :new_app client command with:
      | image_stream | openshift/qe-ruby-25-rhel8:latest            |
      | app_repo     | https://github.com/sclorg/s2i-ruby-container |
      | context_dir  | 2.5/test/puma-test-app                       |
      | name         | ruby25rhel8                                  |
    Then the step should succeed
    And the "ruby25rhel8-1" build completed
    And a pod becomes ready with labels:
      | deployment=ruby25rhel8-1 |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
    Then the output should contain:
      | Min threads: 0, max threads: 16 |
    When I run the :set_env client command with:
      | e        | PUMA_MIN_THREADS=1  |
      | e        | PUMA_MAX_THREADS=12 |
      | e        | PUMA_WORKERS=5      |
      | resource | dc/ruby25rhel8      |
    And a pod becomes ready with labels:
      | deployment=ruby25rhel8-2 |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
    Then the output should contain:
      | Process workers: 5              |
      | Min threads: 1, max threads: 12 |

  # @author xiuwang@redhat.com
  # @case_id OCP-22953
  @admin
  @inactive
  Scenario: Enable hot deploy for ruby app with ruby rhel8 image
    Given I have a project
    When I run the :tag admin command with:
      | source           | registry.redhat.io/rhel8/ruby-25:latest |
      | dest             | qe-ruby-25-rhel8:latest                 |
      | reference_policy | local                                   |
      | n                | openshift                               |
    Then the step should succeed
    When I run the :new_app client command with:
      | image_stream | openshit/qe-ruby-25-rhel8                            |
      | app_repo     | https://github.com/openshift-qe/hot-deploy-ruby.git  |
      | env          | RACK_ENV=development                                 |
      | name         | hotdeploy                                            |
    Then the step should succeed
    And a pod becomes ready with labels:
      | deployment=hotdeploy-1 |
    When I execute on the pod:
      | sed | -i | s/Hello/hotdeploy_test/g  | app.rb |
    Then the step should succeed
    When I expose the "hotdeploy" service
    Then I wait for a web server to become available via the "hotdeploy" route
    And the output should contain "hotdeploy_test"

  # @author xiuwang@redhat.com
  # @case_id OCP-22595
  @admin
  @proxy
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: mysql persistent template
    Given I have a project
    When I run the :tag admin command with:
      | source           | registry.redhat.io/rhel8/mysql-80:latest |
      | dest             | qe-mysql-80-rhel8:latest                 |
      | reference_policy | local                                    |
      | n                | openshift                                |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mysql-persistent-template.json |
    Then the step should succeed
    Given I replace resource "template" named "mysql-persistent" saving edit to "tmp-out.json":
      | mysql:${MYSQL_VERSION} | qe-mysql-80-rhel8:latest |
    When I run the :new_app client command with:
      | template | <%= project.name %>/mysql-persistent |
      | param    | MYSQL_USER=user                      |
      | param    | MYSQL_PASSWORD=user          	|
    Then the step should succeed
    And the "mysql" PVC becomes :bound within 300 seconds
    And a pod becomes ready with labels:
      | name=mysql|
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h 127.0.0.1 -u user -puser -D sampledb -e 'create table test (age INTEGER(32));' |
    Then the step should succeed
    """
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c   |
      |mysql -h 127.0.0.1 -u user -puser -D sampledb -e 'insert into test VALUES(10);' |
    Then the step should succeed
    """
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h 127.0.0.1 -u user -puser -D sampledb -e 'select * from  test;' |
    Then the step should succeed
    """
    And the output should contain:
      | 10 |

  # @author wewang@redhat.com
  # @case_id OCP-22958
  @admin
  @proxy
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Create mysql service from imagestream via oc new-app mysql-rhel8 image
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mysql:latest |
      | env          | MYSQL_USER=user        |
      | env          | MYSQL_PASSWORD=pass    |
      | env          | MYSQL_DATABASE=db      |
      | name         | qe-mysql-80-rhel8      |
    Then the step should succeed
    Given I wait for the "qe-mysql-80-rhel8" service to become ready
    And I get the service pods
    When I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h $QE_MYSQL_80_RHEL8_SERVICE_HOST -uuser -ppass -e "show databases" |
    Then the step should succeed
    """
    Then the output should contain "db"
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h $QE_MYSQL_80_RHEL8_SERVICE_HOST -uuser -ppass   -e "use db;create table test (name VARCHAR(20))" |
    Then the step should succeed
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h $QE_MYSQL_80_RHEL8_SERVICE_HOST -uuser -ppass   -e "use db;insert into test VALUES('openshift')" |
    Then the step should succeed
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h $QE_MYSQL_80_RHEL8_SERVICE_HOST -uuser -ppass  -e "use db;select * from test" |
    Then the output should contain:
      | name      |
      | openshift |

  # @author xiuwang@redhat.com
  # @case_id OCP-31249
  @admin
  @inactive
  Scenario: Using new-app cmd to create app with ruby rhel8 image test
    Given I have a project
    When I run the :tag admin command with:
      | source           | registry.redhat.io/rhel8/ruby-25:latest |
      | dest             | qe-ruby-25-rhel8:latest                 |
      | reference_policy | local                                   |
      | n                | openshift                               |
    Then the step should succeed
    When I run the :new_app client command with:
      | image_stream | openshift/qe-ruby-25-rhel8:latest            |
      | app_repo     | https://github.com/sclorg/s2i-ruby-container |
      | context_dir  | 2.5/test/puma-test-app                       |
      | name         | ruby25rhel8                                  |
    Then the step should succeed
    And the "ruby25rhel8-1" build completed
    And a pod becomes ready with labels:
      | deployment=ruby25rhel8 |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
    Then the output should contain:
      | Min threads: 0, max threads: 16 |
    When I run the :set_env client command with:
      | e        | PUMA_MIN_THREADS=1     |
      | e        | PUMA_MAX_THREADS=12    |
      | e        | PUMA_WORKERS=5         |
      | resource | deployment/ruby25rhel8 |
    And a pod becomes ready with labels:
      | deployment=ruby25rhel8 |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
    Then the output should contain:
      | Process workers: 5              |
      | Min threads: 1, max threads: 12 |
