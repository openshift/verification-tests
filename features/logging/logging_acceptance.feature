Feature: Logging smoke test case

  # @author gkarager@redhat.com
  # @case_id OCP-37508
  @admin
  @destructive
  @flaky
  Scenario: One logging acceptance case for all cluster
# Deploy cluster-logging operator via web console
    Given logging channel name is stored in the :logging_channel clipboard	
    Given logging service is removed successfully	
    Given "elasticsearch-operator" packagemanifest's catalog source name is stored in the :eo_opsrc clipboard		
    Given "cluster-logging" packagemanifest's catalog source name is stored in the :clo_opsrc clipboard	
    Given I switch to the first user	
    Given the first user is cluster-admin	
    Given I open admin console in a browser	
    # subscribe cluster-logging-operator	
    When I perform the :goto_operator_subscription_page web action with:	
      | package_name     | cluster-logging     |	
      | catalog_name     | <%= cb.clo_opsrc %> |	
      | target_namespace | openshift-logging   |	
    Then the step should succeed	
    And I perform the :set_custom_channel_and_subscribe web action with:	
      | update_channel    | <%= cb.logging_channel %> |	
      | install_mode      | OwnNamespace              |	
      | approval_strategy | Automatic                 |	
    Given cluster logging operator is ready	
    # subscribe elasticsearch-operator
    When I perform the :goto_operator_subscription_page web action with:	
      | package_name     | elasticsearch-operator        |	
      | catalog_name     | <%= cb.eo_opsrc %>            |	
      | target_namespace | openshift-operators-redhat    |	
    Then the step should succeed	
    When I perform the :set_custom_channel_and_subscribe web action with:	
      | update_channel    | <%= cb.logging_channel %> |	
      | install_mode      | AllNamespace              |	
      | approval_strategy | Automatic                 |	
    Then the step should succeed
    Given elasticsearch operator is ready in the "openshift-operators-redhat" namespace
    Then I use the "openshift-logging" project
    And default storageclass is stored in the :default_sc clipboard
    Given I obtain test data file "logging/clusterlogging/clusterlogging-storage-template.yaml"
    When I process and create:
      | f | clusterlogging-storage-template.yaml    |
      | p | STORAGE_CLASS=<%= cb.default_sc.name %> |
      | p | PVC_SIZE=10Gi                           |
      | p | ES_NODE_COUNT=1                         |
      | p | REDUNDANCY_POLICY=ZeroRedundancy        |
    Then the step should succeed
    Given I wait for the "instance" clusterloggings to appear   
# Console Dashboard
    When I run the :goto_monitoring_db_cluster_logging web action
    Then the step should succeed
    Given evaluation of `["Elastic Cluster Status", "Elastic Nodes", "Elastic Shards", "Elastic Documents", "Total Index Size on Disk", "Elastic Pending Tasks", "Elastic JVM GC time", "Elastic JVM GC Rate", "Elastic Query/Fetch Latency | Sum", "Elastic Query Rate | Top 5", "CPU", "Elastic JVM Heap Used", "Elasticsearch Disk Usage", "File Descriptors In Use", "FluentD emit count", "FluentD Buffer Availability", "Elastic rx bytes", "Elastic Index Failure Rate", "FluentD Output Error Rate"]` is stored in the :cards clipboard
    And I repeat the following steps for each :card in cb.cards:
    """
    When I perform the :check_monitoring_dashboard_card web action with:
      | card_name | #{cb.card} |
    Then the step should succeed
    """
    And I close the current browser
# ES Metrics
    Given I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").port == "elasticsearch"
    And the expression should be true> service_monitor('monitor-elasticsearch-cluster').service_monitor_endpoint_spec(server_name: "elasticsearch-metrics.openshift-logging.svc").path == "/_prometheus/metrics"
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?          |
      | query | es_cluster_nodes_number |
    Then the step should succeed
    And the expression should be true>  @result[:parsed]['data']['result'][0]['value']
    """
# Fluentd Metrics
    Given I use the "openshift-logging" project
    Given I wait for the "fluentd" service_monitor to appear
    Given the expression should be true> service_monitor('fluentd').service_monitor_endpoint_spec(server_name: "fluentd.openshift-logging.svc").port == "metrics"
    And the expression should be true> service_monitor('fluentd').service_monitor_endpoint_spec(server_name: "fluentd.openshift-logging.svc").path == "/metrics"
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                            |
      | query | fluentd_output_status_buffer_queue_length |
    Then the step should succeed
    And the expression should be true>  @result[:parsed]['data']['result'][0]['value']
    """
# Kibana Access
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
    And I close the current browser
# Data Check
# Authorization
    Given I switch to the second user
    And the second user is cluster-admin
    Given evaluation of `user.cached_tokens.first` is stored in the :user_token clipboard
    And I use the "openshift-logging" project
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?format=JSON' -d '{"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
      | op           | GET                                                                                                     |
      | token        | <%= cb.user_token %>                                                                                    |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?format=JSON |
      | op           | GET                       |
      | token        | <%= cb.user_token %>      |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?format=JSON |
      | op           | GET                     |
      | token        | <%= cb.user_token %>    |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
# Cronjob
    Given the expression should be true> cluster_logging('instance').management_state == "Managed"
    And the expression should be true> elasticsearch('elasticsearch').management_state == "Managed"
    Given evaluation of `cron_job('curator').schedule` is stored in the :curator_schedule_1 clipboard
    Then the expression should be true> cb.curator_schedule_1 == cluster_logging('instance').curation_schedule
    When I run the :patch client command with:
      | resource      | clusterlogging                                                    |
      | resource_name | instance                                                          |
      | p             | {"spec": {"curation": {"curator": {"schedule": "*/15 * * * *"}}}} |
      | type          | merge                                                             |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').curation_schedule == "*/15 * * * *"
    And I wait up to 180 seconds for the steps to pass:
    """
    Given the expression should be true> cron_job('curator').schedule(cached: false, quiet: true) == "*/15 * * * *"
    """
    When I run the :patch client command with:
      | resource      | cronjob                                 |
      | resource_name | curator                                 |
      | p             | {"spec": {"schedule": "*/20 * * * *" }} |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """"
    Given the expression should be true> cron_job('curator').schedule(cached: false, quiet: true) == "*/15 * * * *"
    """
