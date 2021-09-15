Feature: scaling related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-10626
  @proxy
  @gcp-upi
  @gcp-ipi
  @aws-upi
  Scenario: Scale replicas via replicationcontrollers and deploymentconfig
    Given I have a project
    And I create a new application with:
      | image_stream | openshift/perl:5.26                          |
      | name         | myapp                                        |
      | code         | https://github.com/sclorg/s2i-perl-container |
      | context_dir  | 5.26/test/sample-test-app/                   |
    Then the step should succeed
    And the "myapp-1" build was created
    Given the "myapp-1" build completes
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
