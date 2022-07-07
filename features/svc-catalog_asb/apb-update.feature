Feature: Update sql apb related feature

  # @author zitang@redhat.com
  @admin
  @inactive
  Scenario Outline: Plan of serviceinstance can be updated
    Given I save the first service broker registry prefix to :prefix clipboard
    #provision postgresql
    And I have a project
    Given I obtain test data file "svc-catalog/serviceinstance-template.yaml"
    When I process and create:
      | f | serviceinstance-template.yaml |
      | p | INSTANCE_NAME=<db_name>                                                                                      |
      | p | CLASS_EXTERNAL_NAME=<db_name>                                                                                |
      | p | PLAN_EXTERNAL_NAME=<db_plan_1>                                                                               |
      | p | SECRET_NAME=<secret_name>                                                                                    |
      | p | INSTANCE_NAMESPACE=<%= project.name %>                                                                       |
    Then the step should succeed
    And evaluation of `service_instance("<db_name>").uid` is stored in the :db_uid clipboard
    Given I obtain test data file "svc-catalog/serviceinstance-parameters-template.yaml"
    When I process and create:
      | f | serviceinstance-parameters-template.yaml                 |
      | p | SECRET_NAME=<secret_name>                                                                                                               |
      | p | INSTANCE_NAME=<db_name>                                                                                                                 |
      | p | PARAMETERS={"postgresql_database":"admin","postgresql_user":"admin","postgresql_version":"<db_version>","postgresql_password":"test"}   |
      | p | UID=<%= cb.db_uid %>                                                                                                                    |
      | n | <%= project.name %>                                                                                                                     |
    Then the step should succeed
    Given I wait for the "<db_name>" service_instance to become ready up to 360 seconds
    And dc with name matching /postgresql/ are stored in the :dc_1 clipboard
    And a pod becomes ready with labels:
      | deploymentconfig=<%= cb.dc_1.first.name %> |

    # update instance
     When I run the :patch client command with:
      | resource  | serviceinstance/<db_name>      |
      | p         |{                                                     |
      |           | "spec": {                                            |
      |           |    "clusterServicePlanExternalName": "<db_plan_2>"   |
      |           |  }                                                   |
      |           |}                                                     |
    Then the step should succeed
    #checking the old dc is deleted, new dc is created
    Given I wait for the resource "dc" named "<%= cb.dc_1.first.name %>" to disappear within 240 seconds
    Given I wait for the "<db_name>" service_instance to become ready up to 240 seconds
    When I run the :describe client command with:
      | resource  | serviceinstance/<db_name>      |
    Then the step should succeed
    And the output should match:
      | Reason:\\s+InstanceUpdatedSuccessfully |
    And the output should not contain:
      | UpdateInstanceCallFailed |
    And dc with name matching /postgresql/ are stored in the :dc_2 clipboard
    And a pod becomes ready with labels:
      | deploymentconfig=<%= cb.dc_2.first.name %> |

     Examples:
      | case_id   | db_name                         | db_plan_1 | db_plan_2 | secret_name                                | db_version |
      | OCP-16151 | <%= cb.prefix %>-postgresql-apb | prod      | dev       | <%= cb.prefix %>-postgresql-apb-parameters | 9.5        | # @case_id OCP-16151
      | OCP-18249 | <%= cb.prefix %>-postgresql-apb | dev       | prod      | <%= cb.prefix %>-postgresql-apb-parameters | 9.5        | # @case_id OCP-18249

