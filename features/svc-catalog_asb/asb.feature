Feature: Ansible-service-broker related scenarios

  # @author jiazha@redhat.com
  @admin
  @smoke
  @gcp-upi
  @gcp-ipi
  @aws-upi
  Scenario Outline: Provison mediawiki & DB application
    Given I have a project
    And evaluation of `project.name` is stored in the :org_proj_name clipboard
    # Get the registry name from the configmap
    When I switch to cluster admin pseudo user
    And I use the "openshift-ansible-service-broker" project
    And evaluation of `YAML.load(config_map('broker-config').value_of('broker-config'))['registry'][0]['name']` is stored in the :prefix clipboard
    # need to swtich back to normal user mode
    And I switch to the first user
    And I use the "<%= cb.org_proj_name %>" project

    # Provision mediawiki apb
    Given I obtain test data file "svc-catalog/serviceinstance-template.yaml"
    When I process and create:
      | f | serviceinstance-template.yaml |
      | p | INSTANCE_NAME=<%= cb.prefix %>-mediawiki-apb          |
      | p | CLASS_EXTERNAL_NAME=<%= cb.prefix %>-mediawiki-apb    |
      | p | SECRET_NAME=<%= cb.prefix %>-mediawiki-apb-parameters |
      | p | INSTANCE_NAMESPACE=<%= project.name %>                |
    Then the step should succeed
    And evaluation of `service_instance(cb.prefix + "-mediawiki-apb").uid(user: user)` is stored in the :mediawiki_uid clipboard
    Given I obtain test data file "svc-catalog/serviceinstance-parameters-template.yaml"
    When I process and create:
      | f  | serviceinstance-parameters-template.yaml |
      | p | SECRET_NAME=<%= cb.prefix %>-mediawiki-apb-parameters |
      | p | INSTANCE_NAME=<%= cb.prefix %>-mediawiki-apb          |
      | p | UID=<%= cb.mediawiki_uid %>                           |
      | n | <%= project.name %>                                   |
    Then the step should succeed

    # Provision DB apb
    Given I obtain test data file "svc-catalog/serviceinstance-template.yaml"
    When I process and create:
      | f | serviceinstance-template.yaml |
      | p | INSTANCE_NAME=<db_name>                               |
      | p | CLASS_EXTERNAL_NAME=<db_name>                         |
      | p | PLAN_EXTERNAL_NAME=<db_plan>                          |
      | p | SECRET_NAME=<db_secret_name>                          |
      | p | INSTANCE_NAMESPACE=<%= project.name %>                |
    Then the step should succeed
    And evaluation of `service_instance("<db_name>").uid(user: user)` is stored in the :db_uid clipboard
    Given I obtain test data file "svc-catalog/serviceinstance-parameters-template.yaml"
    When I process and create:
      | f | serviceinstance-parameters-template.yaml |
      | p | SECRET_NAME=<db_secret_name>                                                                                            |
      | p | INSTANCE_NAME=<db_name>                                                                                                 |
      | p | PARAMETERS=<db_parameters>                                                                                              |
      | p | UID=<%= cb.db_uid %>                                                                                            |
      | n | <%= project.name %>                                                                                                     |
    Then the step should succeed
    And I wait for all service_instance in the project to become ready up to 360 seconds

    Given dc with name matching /mediawiki/ are stored in the :app clipboard
    And a pod becomes ready with labels:
      | deployment=<%= cb.app.first.name %>-1 |
    And evaluation of `pod` is stored in the :app_pod clipboard
    And dc with name matching /<db_pattern>/ are stored in the :db clipboard

    And a pod becomes ready with labels:
      | deployment=<%= cb.db.first.name %>-1 |
    And evaluation of `pod.name` is stored in the :db_pod_name clipboard

    Then I wait up to 80 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance                            |
    Then the step should succeed
    And the output should match 2 times:
      | Message:\\s+The instance was provisioned successfully |
    """

    # Create servicebinding of DB apb
    Given I obtain test data file "svc-catalog/servicebinding-template.yaml"
    When I process and create:
      | f | servicebinding-template.yaml |
      | p | BINDING_NAME=<db_name>                                                                                      |
      | p | INSTANCE_NAME=<db_name>                                                                                     |
      | p | SECRET_NAME=<db_credentials>                                                                                |
      | n | <%= project.name %>                                                                                         |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | servicebinding                 |
    Then the output should match:
      | Message:\\s+Injected bind result          |
    """

    # Add credentials to mediawiki application
    When I run the :patch client command with:
      | resource      | dc                        |
      | resource_name | <%= cb.app.first.name %>  |
      | p             | {"spec":{"template":{"spec":{"containers":[{"envFrom": [ {"secretRef":{ "name": "<db_credentials>"}}],"name": "<%= cb.app_pod.containers.first.name %>"}]}}}} |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=<%= cb.app.first.name %>-2     |
    And evaluation of `pod.name` is stored in the :app_pod_name clipboard

    # Access mediawiki's route
    And I wait up to 180 seconds for the steps to pass:
    """
    When I open web server via the "http://<%= route(cb.app.first.name).dns %>/index.php/Main_Page" url
    And the output should match "MediaWiki has been(?: successfully)? installed"
    """

    # Delete the servicebinding
    When I run the :delete client command with:
      | object_type        | servicebinding       |
      | object_name_or_id  | <db_name>            |
      | n                  | <%= project.name %>  |
    Then the step should succeed
    Given I wait for the resource "secret" named "<db_credentials>" to disappear within 180 seconds
    And I wait for the resource "servicebinding" named "<db_name>" to disappear within 180 seconds

    # Delete the serviceinstance
    When I run the :delete client command with:
      | object_type       | serviceinstance                   |
      | object_name_or_id | <db_name>                         |
      | object_name_or_id | <%= cb.prefix %>-mediawiki-apb    |
      | n                 | <%= project.name %>               |
    Then the step should succeed
    When I wait for the resource "serviceinstance" named "<db_name>" to disappear within 300 seconds
    And I wait for the resource "serviceinstance" named "<%= cb.prefix %>-mediawiki-apb" to disappear within 300 seconds
    And I wait for the resource "secret" named "<%= cb.prefix %>-mediawiki-apb-parameters" to disappear within 120 seconds
    And I wait for the resource "secret" named "<db_secret_name>" to disappear within 120 seconds
    And I wait for the resource "pod" named "<%= cb.app_pod_name %>" to disappear within 120 seconds
    And I wait for the resource "pod" named "<%= cb.db_pod_name %>" to disappear within 120 seconds

    Then I check that there are no pods in the project
    And I check that there are no dc in the project
    And I check that there are no rc in the project
    And I check that there are no services in the project
    And I check that there are no routes in the project

    Examples:
      | db_name                         | db_credentials                              | db_plan | db_secret_name                             | db_parameters                                                                                                                         | db_pattern           |
      | <%= cb.prefix %>-postgresql-apb | <%= cb.prefix %>-postgresql-apb-credentials |  dev    | <%= cb.prefix %>-postgresql-apb-parameters | {"postgresql_database":"admin","postgresql_user":"admin","postgresql_version":"9.5","postgresql_password":"test"}                     | postgresql | # @case_id OCP-15648
      | <%= cb.prefix %>-postgresql-apb | <%= cb.prefix %>-postgresql-apb-credentials |  prod   | <%= cb.prefix %>-postgresql-apb-parameters | {"postgresql_database":"admin","postgresql_user":"admin","postgresql_version":"9.5","postgresql_password":"test"}                     | postgresql | # @case_id OCP-17363
      | <%= cb.prefix %>-mysql-apb      | <%= cb.prefix %>-mysql-apb-credentials      |  dev    | <%= cb.prefix %>-mysql-apb-parameters      | {"mysql_database":"devel","mysql_user":"devel","mysql_version":"5.7","service_name":"mysql","mysql_password":"test"}                  | mysql      | # @case_id OCP-16071
      | <%= cb.prefix %>-mysql-apb      | <%= cb.prefix %>-mysql-apb-credentials      |  prod   | <%= cb.prefix %>-mysql-apb-parameters      | {"mysql_database":"devel","mysql_user":"devel","mysql_version":"5.7","service_name":"mysql","mysql_password":"test"}                  | mysql      | # @case_id OCP-17361
      | <%= cb.prefix %>-mariadb-apb    | <%= cb.prefix %>-mariadb-apb-credentials    |  dev    | <%= cb.prefix %>-mariadb-apb-parameters    | {"mariadb_database":"admin","mariadb_user":"admin","mariadb_version":"10.2","mariadb_root_password":"test","mariadb_password":"test"} | mariadb    | # @case_id OCP-15350
      | <%= cb.prefix %>-mariadb-apb    | <%= cb.prefix %>-mariadb-apb-credentials    |  prod   | <%= cb.prefix %>-mariadb-apb-parameters    | {"mariadb_database":"admin","mariadb_user":"admin","mariadb_version":"10.2","mariadb_root_password":"test","mariadb_password":"test"} | mariadb    | # @case_id OCP-17362

  # @author chezhang@redhat.com
  @admin
  @inactive
  Scenario Outline: Multiple Plans support for DB APBs
    # Get the registry name from the configmap
    When I switch to cluster admin pseudo user
    And I use the "openshift-ansible-service-broker" project
    And I save the first service broker registry prefix to :prefix clipboard

    # Swtich back to normal user and create first project
    And I switch to the first user
    Given I have a project

    # Provision DB apb with dev plan
    Given I obtain test data file "svc-catalog/serviceinstance-template.yaml"
    When I process and create:
      | f | serviceinstance-template.yaml |
      | p | INSTANCE_NAME=<db_name>                                                          |
      | p | CLASS_EXTERNAL_NAME=<db_name>                                                    |
      | p | PLAN_EXTERNAL_NAME=dev                                                           |
      | p | SECRET_NAME=<db_secret_name>                                                     |
      | p | INSTANCE_NAMESPACE=<%= project.name %>                                           |
    Then the step should succeed
    And evaluation of `service_instance("<db_name>").uid` is stored in the :uid1 clipboard
    Given I obtain test data file "svc-catalog/serviceinstance-parameters-template.yaml"
    When I process and create:
      | f | serviceinstance-parameters-template.yaml |
      | p | SECRET_NAME=<db_secret_name>                                                                |
      | p | INSTANCE_NAME=<db_name>                                                                     |
      | p | PARAMETERS=<db_parameters>                                                                  |
      | p | UID=<%= cb.uid1 %>                                                                          |
      | n | <%= project.name %>                                                                         |
    Then the step should succeed

    Given I wait for the "<db_name>" service_instance to become ready up to 360 seconds
    And dc with name matching /<db_pattern>/ are stored in the :db clipboard
    And a pod becomes ready with labels:
      | deployment=<%= cb.db.first.name %>-1 |

    # Create another project
    Given I create a new project

    # Provision DB apb with prod plan
    Given I obtain test data file "svc-catalog/serviceinstance-template.yaml"
    When I process and create:
      | f | serviceinstance-template.yaml |
      | p | INSTANCE_NAME=<db_name>                                                          |
      | p | CLASS_EXTERNAL_NAME=<db_name>                                                    |
      | p | PLAN_EXTERNAL_NAME=prod                                                          |
      | p | SECRET_NAME=<db_secret_name>                                                     |
      | p | INSTANCE_NAMESPACE=<%= project.name %>                                           |
    Then the step should succeed
    And evaluation of `service_instance("<db_name>").uid` is stored in the :uid2 clipboard
    Given I obtain test data file "svc-catalog/serviceinstance-parameters-template.yaml"
    When I process and create:
      | f | serviceinstance-parameters-template.yaml |
      | p | SECRET_NAME=<db_secret_name>                                                                |
      | p | INSTANCE_NAME=<db_name>                                                                     |
      | p | PARAMETERS=<db_parameters>                                                                  |
      | p | UID=<%= cb.uid2 %>                                                                          |
      | n | <%= project.name %>                                                                         |
    Then the step should succeed

    Given I wait for the "<db_name>" service_instance to become ready up to 360 seconds
    And dc with name matching /<db_pattern>/ are stored in the :db clipboard
    And a pod becomes ready with labels:
      | deployment=<%= cb.db.first.name %>-1 |

    Examples:
      | db_name                         | db_secret_name                             | db_parameters                                                                                                                         | db_pattern |
      | <%= cb.prefix %>-postgresql-apb | <%= cb.prefix %>-postgresql-apb-parameters | {"postgresql_database":"admin","postgresql_user":"admin","postgresql_version":"9.5","postgresql_password":"test"}                     | postgresql | # @case_id OCP-15328
      | <%= cb.prefix %>-mariadb-apb    | <%= cb.prefix %>-mariadb-apb-parameters    | {"mariadb_database":"admin","mariadb_user":"admin","mariadb_version":"10.2","mariadb_root_password":"test","mariadb_password":"test"} | mariadb    | # @case_id OCP-16086
      | <%= cb.prefix %>-mysql-apb      | <%= cb.prefix %>-mysql-apb-parameters      | {"mysql_database":"devel","mysql_user":"devel","mysql_version":"5.7","service_name":"mysql","mysql_password":"test"}                  | mysql      | # @case_id OCP-16087

  # @author zitang@redhat.com
  # @case_id OCP-15354
  @admin
  @inactive
  Scenario: Check multiple broker support for service catalog
    Given admin checks that the "ansible-service-broker" cluster_service_broker exists
    And admin checks that the "template-service-broker" cluster_service_broker exists

    #Check ansible-service-broker  and template-service-broker run successfully
    When I switch to cluster admin pseudo user
    And I run the :describe client command with:
      | resource | clusterservicebroker/ansible-service-broker   |
    Then the output should match "Message:\s+Successfully fetched catalog entries from broker"
    When I run the :describe client command with:
      | resource | clusterservicebroker/template-service-broker  |
    Then the output should match "Message:\s+Successfully fetched catalog entries from broker"

