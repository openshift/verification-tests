@clusterlogging
Feature: Kibana related features

  # @author qitang@redhat.com
  # @case_id OCP-25599
  @admin
  @destructive
  @commonlogging
  @gcp-upi
  @gcp-ipi
  Scenario: Show logs on Kibana web console according to different user role
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    And I wait for the "kibana" route to appear
    And I wait for the "project.<%= cb.proj.name %>" index to appear in the ES pod with labels "es-node-master=true"
    Given I switch to the first user
    And I login to kibana logging web console
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | project.<%= cb.proj.name %>.<%= cb.proj.uid %>.* |
    Then the step should succeed
    When I run the :logout_kibana web action
    Then the step should succeed
    And I close the current browser
    Given cluster role "cluster-admin" is added to the "first" user
    Then I login to kibana logging web console
    Given evaluation of `[".operations.*", ".all", ".orphaned", "project.*"]` is stored in the :indices clipboard
    And I run the :kibana_expand_index_patterns web action
    Then the step should succeed
    Given I repeat the following steps for each :index_name in cb.indices:
    """
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | #{cb.index_name} |
    Then the step should succeed
    """
    When I run the :logout_kibana web action
    Then the step should succeed
    And I close the current browser
    And cluster role "cluster-admin" is removed from the "first" user

    And I login to kibana logging web console
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | project.<%= cb.proj.name %>.<%= cb.proj.uid %>.* |
    Then the step should succeed
    And I run the :kibana_expand_index_patterns web action
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | .operations.* |
    Then the step should fail

  # @author qitang@redhat.com
  # @case_id OCP-30362
  @admin
  @destructive
  @commonlogging
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: Normal User can only view logs out of the projects owned by himself --kibana
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    Given I switch to the first user
    When I login to kibana logging web console
    Then the step should succeed
    Given I have index pattern "*app"
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    And I run the :go_to_kibana_discover_page web action
    Then the step should succeed
    """
    # check the log count, wait for the Kibana console to be loaded
    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | *app |
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I run the :check_log_count web action
    Then the step should succeed
    """
    # Verify the token are encrypted in kibana logs
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given a pod becomes ready with labels:
      | logging-infra=kibana |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
      | c             | kibana          |
    Then the output should contain:
      | "x-forwarded-access-token":"XXXXXXXXXXXXXX |
      | "x-forwarded-email":"XXXXXXXXXXXXXX        |

  # @author qitang@redhat.com
  # @case_id OCP-30361
  @admin
  @destructive
  @commonlogging
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  Scenario: User with cluster-admin role can show logs out of all projects -- kibana
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to the second user
    And the second user is cluster-admin
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    Given I wait for the "infra" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    When I login to kibana logging web console
    Then the step should succeed
    Given I have index pattern "*app"
    Then the step should succeed
    Given I have index pattern "*infra"
    Then the step should succeed
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    And I run the :go_to_kibana_discover_page web action
    Then the step should succeed
    """

    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | *app |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run the :check_log_count web action
    Then the step should succeed
    """
    And I run the :kibana_expand_index_patterns web action
    Then the step should succeed
    When I perform the :kibana_click_index web action with:
      | index_pattern_name | *infra |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | *infra |
    Then the step should succeed
    When I run the :check_log_count web action
    Then the step should succeed
    """

  # @author qitang@redhat.com
  # @case_id OCP-32002
  @admin
  @destructive
  @commonlogging
  @gcp-upi
  @gcp-ipi
  Scenario: Kibana logout function should log off user
    Given the master version < "4.5"
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given the first user is cluster-admin
    And I use the "openshift-logging" project
    And I wait for the "project.<%= cb.proj_name %>" index to appear in the ES pod with labels "es-node-master=true"
    And evaluation of `route('kibana', service('kibana',project('openshift-logging', switch: false))).dns(by: admin)` is stored in the :kibana_url clipboard
    When I login to kibana logging web console
    Then the step should succeed
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | .operations.* |
    Then the step should succeed
    When I run the :logout_kibana web action
    Then the step should succeed
    Given 10 seconds have passed
    When I access the "https://<%= cb.kibana_url %>" url in the web browser
    Then the step should succeed
    When I perform the :login_kibana web action with:
      | username   | <%= user.name %>             |
      | password   | <%= user.password %>         |
      | idp        | <%= env.idp %>               |
    Then the step should succeed
    # click `Log in with OpenShift` button and login again
    When I run the :logout_kibana web action
    Then the step should succeed
    When I perform the :login_kibana web action with:
      | username   | <%= user.name %>             |
      | password   | <%= user.password %>         |
      | idp        | <%= env.idp %>               |
    Then the step should succeed
