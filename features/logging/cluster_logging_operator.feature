@clusterlogging
Feature: cluster-logging-operator related test

  # @author qitang@redhat.com
  # @case_id OCP-21333
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for collector is deployed along with cluster logging
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

  # @author qitang@redhat.com
  # @case_id OCP-21907
  @admin
  @destructive
  Scenario: Deploy elasticsearch-operator via OLM using CLI
    Given logging operators are installed successfully

  # @author qitang@redhat.com
  # @case_id OCP-22492
  @admin
  @destructive
  Scenario: Scale Elasticsearch nodes by nodeCount 2->3->4 in clusterlogging
    Given I obtain test data file "logging/clusterlogging/scalebase.yaml"
    Given I create clusterlogging instance with:
      | remove_logging_pods | true                                                                   |
      | crd_yaml            | scalebase.yaml |
      | check_status        | false                                                                  |
    Then the step should succeed
    And I wait for the "elasticsearch" elasticsearches to appear up to 300 seconds
    And the expression should be true> cluster_logging('instance').logstore_node_count == 2
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] == 2
    Given I wait up to 300 seconds for the steps to pass:
    """
    Given evaluation of `elasticsearch('elasticsearch').nodes[0]['genUUID']` is stored in the :gen_uuid_1 clipboard
    And the expression should be true> cb.gen_uuid_1 != nil
    """
    Then I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1 %>-1" deployment to appear up to 300 seconds
    And I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1 %>-2" deployment to appear up to 300 seconds
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":3}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_node_count == 3
    Given I wait for the steps to pass:
    """
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] == 3
    """
    And I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1%>-3" deployment to appear up to 300 seconds
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":4}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_node_count == 4
    Given I wait for the steps to pass:
    """
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] + elasticsearch('elasticsearch').nodes[1]['nodeCount'] == 4
    """
    Given I wait for the steps to pass:
    """
    Given evaluation of `elasticsearch('elasticsearch').nodes[1]['genUUID']` is stored in the :gen_uuid_2 clipboard
    And the expression should be true> cb.gen_uuid_2 != nil
    """
    And I wait for the "elasticsearch-cd-<%= cb.gen_uuid_2 %>-1" deployment to appear up to 300 seconds

  # @author qitang@redhat.com
  # @case_id OCP-23738
  @admin
  @destructive
  Scenario: Fluentd alert rule: FluentdNodeDown
    Given the master version >= "4.2"
    Given I obtain test data file "logging/clusterlogging/example.yaml"
    Given I create clusterlogging instance with:
      | remove_logging_pods | true                                                                 |
      | crd_yaml            | example.yaml |
    Then the step should succeed
    Given I wait for the "fluentd" prometheus_rule to appear
    And I wait for the "fluentd" service_monitor to appear
    # make all fluentd pods down
    When I run the :patch client command with:
      | resource      | clusterlogging                                                                        |
      | resource_name | instance                                                                              |
      | p             | {"spec": {"collection": {"logs": {"fluentd":{"nodeSelector": {"logging": "test"}}}}}} |
      | type          | merge                                                                                 |
    Then the step should succeed
    And I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                      |
      | query | ALERTS{alertname="FluentdNodeDown"} |
    Then the step should succeed
    And the output should match:
      | "alertstate":"pending\|firing" |
    """ 

  # @author qitang@redhat.com
  # @case_id OCP-28131
  @admin
  @destructive
  Scenario: CLO should generate Elasticsearch Index Management
    Given I obtain test data file "logging/clusterlogging/example_indexmanagement.yaml"
    Given I create clusterlogging instance with:
      | remove_logging_pods | true                                                                                 |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given I wait for the "indexmanagement-scripts" config_map to appear
    And evaluation of `["elasticsearch-delete-app", "elasticsearch-delete-audit", "elasticsearch-delete-infra", "elasticsearch-rollover-app", "elasticsearch-rollover-infra", "elasticsearch-rollover-audit"]` is stored in the :cj_names clipboard
    Given I repeat the following steps for each :name in cb.cj_names:
    """
      Given I wait for the "#{cb.name}" cron_job to appear
      And the expression should be true> cron_job('#{cb.name}').schedule == "*/15 * * * *"
    """
    And the expression should be true> elasticsearch('elasticsearch').policy_ref(name: 'app') == "app-policy"
    And the expression should be true> elasticsearch('elasticsearch').delete_min_age(name: "app-policy") == cluster_logging('instance').application_max_age
    And the expression should be true> elasticsearch('elasticsearch').rollover_max_age(name: "app-policy") == "3m"
    And the expression should be true> elasticsearch('elasticsearch').policy_ref(name: 'infra') == "infra-policy"
    And the expression should be true> elasticsearch('elasticsearch').delete_min_age(name: "infra-policy") == cluster_logging('instance').infra_max_age
    And the expression should be true> elasticsearch('elasticsearch').rollover_max_age(name: "infra-policy") == "9m"
    And the expression should be true> elasticsearch('elasticsearch').policy_ref(name: 'audit') == "audit-policy"
    And the expression should be true> elasticsearch('elasticsearch').delete_min_age(name: "audit-policy") == cluster_logging('instance').audit_max_age
    And the expression should be true> elasticsearch('elasticsearch').rollover_max_age(name: "audit-policy") == "1h"

  # @author qitang@redhat.com
  # @case_id OCP-33721
  @admin
  @destructive
  @commonlogging
  Scenario: OpenShift Logging dashboard
    Given I switch to the first user
    And the first user is cluster-admin
    And I open admin console in a browser
    When I run the :goto_monitoring_db_cluster_logging web action
    Then the step should succeed
    Given evaluation of `["Elastic Cluster Status", "Elastic Nodes", "Elastic Shards", "Elastic Documents", "Total Index Size on Disk", "Elastic Pending Tasks", "Elastic JVM GC time", "Elastic JVM GC Rate", "Elastic Query/Fetch Latency | Sum", "Elastic Query Rate | Top 5", "CPU", "Elastic JVM Heap Used", "Elasticsearch Disk Usage", "File Descriptors In Use", "FluentD emit count", "FluentD Buffer Availability", "Elastic rx bytes", "Elastic Index Failure Rate", "FluentD Output Error Rate"]` is stored in the :cards clipboard
    And I repeat the following steps for each :card in cb.cards:
    """
    When I perform the :check_monitoring_dashboard_card web action with:
      | card_name | #{cb.card} |
    Then the step should succeed
    """

  # @author gkarager@redhat.com
  # OCPQE-2773
  @admin
  @destructive
  Scenario: Create one logging acceptance cases for all cluster
    # Logging deployment
    Given logging service is removed successfully	
    Given the logging operators are redeployed after scenario	
    Given logging channel name is stored in the :logging_channel clipboard	
    Given I obtain test data file "logging/clusterlogging/deploy_clo_via_olm/01_clo_ns.yaml"	
    Given I run the :create admin command with:	
      | f | 01_clo_ns.yaml |	
    Then the step should succeed
    Given I obtain test data file "logging/clusterlogging/deploy_eo_via_olm/01_eo_ns.yaml"	
    Given I run the :create admin command with:	
      | f | 01_eo_ns.yaml |	
    Then the step should succeed
    Given I register clean-up steps:	
    """	
    Given logging service is removed successfully	
    Then the step should succeed	
    """	
    Given "cluster-logging" packagemanifest's catalog source name is stored in the :clo_opsrc clipboard	
    Given "elasticsearch-operator" packagemanifest's catalog source name is stored in the :eo_opsrc clipboard	

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
    Given I use the "openshift-operators-redhat" project
    Given elasticsearch operator is ready
    And I close the current browser
  # ES Metrics
  # Data Check
    Given I obtain test data file "logging/clusterlogging/example.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true         |
      | crd_yaml            | example.yaml |
    Then the step should succeed
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
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    And I wait for the "kibana" route to appear
    And I wait for the "project.<%= cb.proj.name %>" index to appear in the ES pod with labels "es-node-master=true"
    Given I switch to the first user
    And I login to kibana logging web console
  # Console Dashboard