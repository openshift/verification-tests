Feature: Machine features testing  
  
  # @author zhsun@redhat.com
  @admin
  Scenario Outline: Testing machine removal when finalizers are used
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario
    And I pick a random machineset to scale
    # Create an invalid machineset
    Given I run the :get admin command with:
      | resource      | machineset              |
      | resource_name | <%= machine_set.name %> |
      | namespace     | openshift-machine-api   |
      | o             | yaml                    |
    Then the step should succeed
    And I save the output to file> machineset-invalid.yaml
    And I replace content in "machineset-invalid.yaml":
      | <%= machine_set.name %> | machineset-invalid |
      | <valid_field>           | <invalid_value>    |
      | /replicas:.*/           | replicas: 1        |

    When I run the :create admin command with:
      | f | machineset-invalid.yaml |
    Then the step should succeed
    And admin ensures "machineset-invalid" machineset is deleted after scenario

    Examples:
      | valid_field                 | invalid_value                       |
      | name: aws-cloud-credentials | name: aws-cloud-credentials-invalid | 
