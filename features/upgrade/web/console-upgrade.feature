Feature: web console related upgrade check
  # @author yanpzhan@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: check console accessibility - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | ui-upgrade |
    Then the step should succeed
    Given I use the "ui-upgrade" project
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create client command with:
      | f | daemonset.yaml |
    Then the step should succeed
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    Given I obtain test data file "deployment/hello-deployment-1.yaml"
    When I run the :create client command with:
      | f | hello-deployment-1.yaml |
    Then the step should succeed
    Given I open admin console in a browser
    When I perform the :create_app_from_imagestream web action with:
      | project_name | ui-upgrade |
      | is_name      | ruby       |
    Then the step should succeed
    When I get project deploymentconfigs
    Then the output should contain "ruby"
    When I perform the :goto_project_resources_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_list_heading_shown web action with:
      | heading | ruby |
    Then the step should succeed
    When I perform the :click_list_item web action with:
      | resource_kind | DaemonSet       |
      | resource_name | hello-daemonset |
    Then the step should succeed
    When I perform the :click_list_item web action with:
      | resource_kind | Deployment      |
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :click_list_item web action with:
      | resource_kind | DeploymentConfig |
      | resource_name | hooks            |
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id OCP-22597
  @upgrade-check
  @admin
  @users=upuser1,upuser2
  Scenario: check console accessibility
    Given the first user is cluster-admin    
    Given I open admin console in a browser
    When I perform the :create_app_from_imagestream web action with:
      | project_name | ui-upgrade |
      | is_name      | python     |
    Then the step should succeed
    Given I use the "ui-upgrade" project
    When I get project deploymentconfigs
    Then the output should contain "python"
    When I perform the :goto_project_resources_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_list_heading_shown web action with:
      | heading | python |
    Then the step should succeed
    When I perform the :check_list_heading_shown web action with:
      | heading | ruby |
    Then the step should succeed
    When I perform the :click_list_item web action with:
      | resource_kind | DaemonSet       |
      | resource_name | hello-daemonset |
    Then the step should succeed         
    When I perform the :click_list_item web action with:
      | resource_kind | Deployment      |
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :click_list_item web action with:
      | resource_kind | DeploymentConfig |
      | resource_name | hooks            |
    Then the step should succeed
