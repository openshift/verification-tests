Feature: Ansible-service-broker related scenarios

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

