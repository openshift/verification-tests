Feature: scaling related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-10626
  Scenario: OCP-10626 Scale replicas via replicationcontrollers and deploymentconfig
    Given I have a project
    And I create a new application with:
      | image_stream | openshift/perl:5.20                   |
      | name         | myapp                                 |
      | code         | https://github.com/sclorg/s2i-perl-container |
      | context_dir  | 5.20/test/sample-test-app/            |
    Then the step should succeed
    When I expose the "myapp" service
    Then the step should succeed
    Given I wait for the "myapp" service to become ready up to 300 seconds
    When I get project replicationcontroller as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :rc_name clipboard
    # get dc name
    When I get project deploymentconfig as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :dc_name clipboard
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 3                 |
    Then the step should succeed
    And I wait until number of replicas match "3" for replicationController "<%= cb.rc_name %>"
    # scale down
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 2                 |
    Then the step should succeed
    And I wait until number of replicas match "2" for replicationController "<%= cb.rc_name %>"
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 0                 |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "<%= cb.rc_name %>"

    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | -3                |
    Then the step should fail
    And the output should contain:
      | error:           |
      | --replicas=COUNT |

  # @author pruan@redhat.com
  # @case_id OCP-11764
  Scenario: OCP-11764 Scale up/down jobs
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511599/job.yaml |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 5    |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+5 |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 1    |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+1 |
      | 1\s+Running      |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 25   |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+25 |

