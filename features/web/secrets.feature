Feature: web secrets related
  # @author yanpzhan@redhat.com
  # @case_id OCP-15549
  Scenario: Add secret to application from the secret page
    Given I have a project
    When I run the :secrets client command with:
      | action | new        |
      | name   | secretone  |
      | source | /dev/null  |
    Then the step should succeed
    When I run the :secrets client command with:
      | action | new        |
      | name   | secrettwo  |
      | source | /dev/null  |
    Then the step should succeed

    When I run the :run client command with:
      | name   | myrun                 |
      | image  | aosqe/hello-openshift |
      | limits | memory=256Mi          |
    Then the step should succeed

    When I perform the :add_secret_to_application_as_env web console action with:
      | project_name | <%= project.name %> |
      | app_name     | myrun               |
      | secret       | secretone           |
    Then the step should succeed
    When I perform the :check_env_from_configmap_or_secret_on_dc_page web console action with:
      | project_name  | <%= project.name %> |
      | dc_name       | myrun               |
      | resource_name | secretone           |
      | resource_type | Secret              |
    Then the step should succeed

    Given a pod becomes ready with labels:
      | deployment=myrun-2 |
 
    When I perform the :add_secret_to_application_as_volume web console action with:
      | project_name | <%= project.name %> |
      | app_name     | myrun               |
      | secret       | secrettwo           |
      | mount_path   | /data               |
    Then the step should succeed
    When I perform the :check_volume_from_secret_on_dc web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | myrun               |
      | secret_name  | secrettwo           |
    Then the step should succeed

