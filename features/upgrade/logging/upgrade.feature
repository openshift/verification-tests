Feature: Logging upgrading related features

  # @author qitang@redhat.com
  @admin
  @destructive
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: Cluster logging checking during cluster upgrade - prepare
    # prepare data
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | logging-upgrade-data-check |
    Then the step should succeed
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    # deploy clusterlogging, enable pvc for ES
    Given logging operators are installed successfully
    And default storageclass is stored in the :default_sc clipboard
    Given I obtain test data file "logging/clusterlogging/clusterlogging-storage-template.yaml"
    When I process and create:
      | f | clusterlogging-storage-template.yaml    |
      | p | STORAGE_CLASS=<%= cb.default_sc.name %> |
      | p | PVC_SIZE=20Gi                           |
      | p | ES_NODE_COUNT=3                         |
      | p | REDUNDANCY_POLICY=SingleRedundancy      |
    Then the step should succeed
    Given I wait for the "fluentd" daemonset to appear up to 300 seconds
    And I wait until ES cluster is ready
    And I wait until fluentd is ready
    And I wait until kibana is ready
    Given I wait for the project "logging-upgrade-data-check" logs to appear in the ES pod
    # check cron jobs
    When I check the cronjob status
    Then the step should succeed

    Given I switch to the first user
    When I login to kibana logging web console
    Then the step should succeed
    Given the "logging-upgrade-data-check" project is deleted

  # @case_id OCP-22911
  # @author qitang@redhat.com
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: Cluster logging checking during cluster upgrade
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    # check logging status
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I wait for the "fluentd" daemonset to appear up to 300 seconds
    And I wait until ES cluster is ready
    And I wait until fluentd is ready
    And I wait until kibana is ready
    # check the logs collected before upgrading
    Given I wait for the project "logging-upgrade-data-check" logs to appear in the ES pod
    # check if logging stack could gather logs
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    And evaluation of `cb.doc_count` is stored in the :docs_count_1 clipboard
    # ensure there are no new PVCs after upgrading
    And the expression should be true> BushSlicer::PersistentVolumeClaim.list(user: user, project: project).count == cluster_logging('instance').logstore_node_count
    # check cron jobs
    When I check the cronjob status
    Then the step should succeed
    # check if kibana console is accessible
    Given I switch to the second user
    And the second user is cluster-admin
    Given I login to kibana logging web console
    Then the step should succeed

    # upgrade logging if needed
    Given I make sure the logging operators match the cluster version
    #check data again
    Given I wait for the project "logging-upgrade-data-check" logs to appear in the ES pod
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    Then the expression should be true> cb.doc_count > cb.docs_count_1
    And evaluation of `cb.doc_count` is stored in the :docs_count_2 clipboard
    # check if the logging still can gather logs
    Given 10 seconds have passed
    When I perform the HTTP request on the ES pod:
      | relative_url | */_count?format=JSON' -d '{"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
      | op           | GET                                                                                                  |
    Then the expression should be true> @result[:parsed]['count'] > cb.docs_count_2
    # check kibana console
    Given I switch to the second user
    When I login to kibana logging web console
    Then the step should succeed
