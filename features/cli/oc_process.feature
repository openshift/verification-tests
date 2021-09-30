Feature: oc_process.feature

  # @author shiywang@redhat.com
  # @case_id OCP-11044
  @aws-ipi
  @proxy
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  Scenario: Supply oc new-app parameter list+env vars via a file
    Given I have a project
    Given a "test1.env" file is created with the following lines:
    """
    MYSQL_DATABASE='test'
    """
    Given a "test2.env" file is created with the following lines:
    """
    APPLE=CLEMENTINE
    """
    Given a "test3.env" file is created with the following lines:
    """
    APPLE=BANANA
    """
    Given a "test4.env" file is created with the following lines:
    """
    MYSQL_DATABASE='abc'
    """
    #1
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo   | application-template-stibuild.json |
      | param_file | test1.env              |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completes
    Given a pod becomes ready with labels:
      | deployment=frontend-1 |
    When I run the :set_env client command with:
      | resource | pods/<%= pod.name %> |
      | list     | true                 |
    And the output should contain:
      | MYSQL_DATABASE=test |
    And I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    And I run the :delete client command with:
      | object_type       | secrets  |
      | object_name_or_id | dbsecret |
    Then the step should succeed
    #2
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo   | application-template-stibuild.json |
      | env_file   | test2.env              |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completes
    Given a pod becomes ready with labels:
      | deployment=frontend-1      |
    When I run the :set_env client command with:
      | resource | pods/<%= pod.name %> |
      | list     | true                 |
    And the output should contain:
      | APPLE=CLEMENTINE |
    And I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    And I run the :delete client command with:
      | object_type       | secrets  |
      | object_name_or_id | dbsecret |
    Then the step should succeed
    #3
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo   | application-template-stibuild.json |
      | param_file | test4.env                     |
      | env_file   | test1.env                     |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completes
    Given a pod becomes ready with labels:
      | deployment=frontend-1      |
    When I run the :set_env client command with:
      | resource | pods/<%= pod.name %> |
      | list     | true                 |
    And the output should contain:
      | MYSQL_DATABASE=test |
    And I run the :delete client command with:
      | object_type | all |
      | all         |     |
    Then the step should succeed
    And I run the :delete client command with:
      | object_type       | secrets  |
      | object_name_or_id | dbsecret |
    Then the step should succeed
    #4
    Given I obtain test data file "build/application-template-stibuild.json"
    When I run the :new_app client command with:
      | app_repo   | application-template-stibuild.json |
      | param_file | test1.env                     |
      | env_file   | test2.env                     |
      | param      | MYSQL_DATABASE=APPLE          |
      | env        | APPLE=PEAR                    |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completes
    Given a pod becomes ready with labels:
      | deployment=frontend-1      |
    When I run the :set_env client command with:
      | resource | pods/<%= pod.name %> |
      | list     | true                 |
    And the output should contain:
      | APPLE=PEAR           |
      | MYSQL_DATABASE=APPLE |

