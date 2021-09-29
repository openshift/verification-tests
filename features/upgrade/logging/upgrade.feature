Feature: Logging upgrading related features

  # @author qitang@redhat.com
  @admin
  @destructive
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: Cluster logging checking during cluster upgrade - prepare
    Given I switch to the first user
    Given I have "json" log pod in project "logging-upg-prep-1"
    And I have "json" log pod in project "logging-upg-prep-share"
    Given I run the :oadm_groups_new admin command with:
      | group_name | project-group-share                |
      | user_name  | <%= user(1, switch: false).name %> |
    Given logging operators are installed successfully
    Given I have clusterlogging with persistent storage ES
    Then I wait for the project "logging-upg-prep-1" logs to appear in the ES pod
    When I check the cronjob status
    Then the step should succeed

    Given I switch to the first user
    When I login to kibana logging web console
    Given I have index pattern "*app"
    Then I can display the pod logs of the "logging-upg-prep-1" project under the "*app" pattern in kibana
    Then I close the current browser
    Given I run the :policy_add_role_to_group client command with:
      | group_name | project-group-share |
      | role       | edit                |
    Then the step should succeed
    Given I switch to the second user
    Given I login to kibana logging web console
    Given I have index pattern "*app"
    Then I can display the pod logs of the "logging-upg-prep-share" project under the "*app" pattern in kibana
    Then I close the current browser

  # @case_id OCP-22911
  # @author qitang@redhat.com
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: Cluster logging checking during cluster upgrade
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Then evaluation of `project.name` is stored in the :proj1 clipboard
    And I have "json" log pod in project "<%= cb.proj1 %>"
    Given I wait for clusterlogging to be functional in the project
    # check the logs collected before upgrading
    # ensure there are no new PVCs after upgrading
    Then the expression should be true> BushSlicer::PersistentVolumeClaim.list(user: user, project: project).count == cluster_logging('instance').logstore_node_count
    And I wait for the project "<%= cb.proj1 %>" logs to appear in the ES pod
    # check if kibana console is accessible
    Given I switch to the first user
    When I login to kibana logging web console
    Then I can display the pod logs of the "logging-upg-prep-1" project under the "*app" pattern in kibana
    Then I close the current browser
    Given I switch to the second user
    When I login to kibana logging web console
    Then I can display the pod logs of the "logging-upg-prep-share" project under the "*app" pattern in kibana
    Then I close the current browser

    # upgrade logging if needed
    Given I make sure the logging operators match the cluster version
    #And I wait for clusterlogging to be functional in the project
    And the expression should be true> BushSlicer::PersistentVolumeClaim.list(user: user, project: project).count == cluster_logging('instance').logstore_node_count
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Then evaluation of `project.name` is stored in the :proj2 clipboard
    Then I have "json" log pod in project "<%= cb.proj2 %>"
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    And I wait for the project "<%= cb.proj2 %>" logs to appear in the ES pod
    # check if kibana console is accessible
    Given I switch to the first user
    When I login to kibana logging web console
    Then I can display the pod logs of the "logging-upg-prep-1" project under the "*app" pattern in kibana
    Then I close the current browser
    Given I switch to the second user
    When I login to kibana logging web console
    Then I can display the pod logs of the "logging-upg-prep-share" project under the "*app" pattern in kibana
    Then I close the current browser
    Given I switch to the first user
    Then The "<%= cb.proj1 %>" project is deleted
    Then The "<%= cb.proj2 %>" project is deleted
