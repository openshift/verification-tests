Feature: env.feature

  # @author shiywang@redhat.com
  # @case_id OCP-11543
  @proxy
  @gcp-upi
  @gcp-ipi
  Scenario: Can set env vars on buildconfig with new-app --env and --env-file
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env      | DB_USER=test                                              |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      |deployment=ruby-hello-world-1|
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "DB_USER=test"
    And I delete all resources from the project
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env      | RACK_ENV=development                                      |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      |deployment=ruby-hello-world-1|
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "RACK_ENV=development"
    And I delete all resources from the project
    Given a "test" file is created with the following lines:
    """
    DB_USER=test
    """
    When I run the :new_app client command with:
      | app_repo | ruby~https://github.com/openshift/ruby-hello-world |
      | env_file | test                                               |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      |deployment=ruby-hello-world-1|
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "DB_USER=test"
    And I delete all resources from the project
    Given a "test" file is created with the following lines:
    """
    RACK_ENV=development
    """
    When I run the :new_app client command with:
      | app_repo | ruby~https://github.com/openshift/ruby-hello-world |
      | env_file | test                                               |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      |deployment=ruby-hello-world-1|
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "RACK_ENV=development"

  # @author wewang@redhat.com
  # @case_id OCP-31247
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Can set env vars on buildconfig with new-app --env and --env-file test
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env      | DB_USER=test                                              |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      | deployment=ruby-hello-world |
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "DB_USER=test"
    And I delete all resources from the project
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env      | RACK_ENV=development                                      |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      | deployment=ruby-hello-world |
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "RACK_ENV=development"
    And I delete all resources from the project
    Given a "test" file is created with the following lines:
    """
    DB_USER=test
    """
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env_file | test                                                   |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      | deployment=ruby-hello-world |
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "DB_USER=test"
    And I delete all resources from the project
    Given a "test" file is created with the following lines:
    """
    RACK_ENV=development
    """
    When I run the :new_app client command with:
      | app_repo | ruby:latest~https://github.com/openshift/ruby-hello-world |
      | env_file | test                                                   |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given a pod becomes ready with labels:
      | deployment=ruby-hello-world |
    When I run the :set_env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    And the output should contain "RACK_ENV=development"
