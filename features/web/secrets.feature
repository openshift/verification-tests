Feature: web secrets related

  # @author xxing@redhat.com
  # @case_id OCP-11386
  Scenario: OCP-11386 Add secret on Create From Image page
    Given I have a project
    When I run the :oc_secrets_new_basicauth client command with:
      | secret_name | gitsecret |
      | username    | user      |
      | password    | 12345678  |
    Then the step should succeed
    When I perform the :create_app_from_image_with_secret web console action with:
      | project_name | <%= project.name %> |
      | image_name   | php                 |
      | image_tag    | latest              |
      | namespace    | openshift           |
      | app_name     | phpdemo             |
      | secret_type  | gitSecret           |
      | secret_name  | gitsecret           |
    Then the step should succeed
    Given the "phpdemo-1" build was created
    When I run the :get client command with:
      | resource      | buildConfig |
      | resource_name | phpdemo     |
      | o             | yaml        |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["spec"]["source"]["sourceSecret"]["name"] == "gitsecret"

  # @author yanpzhan@redhat.com
  # @case_id OCP-15549
  Scenario: OCP-15549 Add secret to application from the secret page
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

