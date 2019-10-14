@clusterlogging
@commonlogging
Feature: Kibana related features

  # @auther qitang@redhat.com
  # @case_id OCP-25599
  @admin
  @destructive
  Scenario: Show logs on Kibana web console according to different user role
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging/loggen/container_json_unicode_log_template.json |
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
    And cluster role "cluster-admin" is removed from the "first" user

    And I login to kibana logging web console
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | project.<%= cb.proj.name %>.<%= cb.proj.uid %>.* |
    Then the step should succeed
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | .operations.* |
    Then the step should fail

