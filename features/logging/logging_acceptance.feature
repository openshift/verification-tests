Feature: Logging smoke test case

  # @author gkarager@redhat.com
  # @case_id OCP-37508
  @admin
  @serial
  @console
  @rosa
  @aro 
  @osd_ccs
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-37508:Logging One logging acceptance case for all cluster
    Given logging operators are installed successfully
    # create a pod to generate some logs
    Given I switch to the second user
    And I have a project
    And evaluation of `project` is stored in the :proj clipboard
    And I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |

    Given I switch to the first user
    Given the first user is cluster-admin
    And evaluation of `user.cached_tokens.first` is stored in the :user_token_1 clipboard
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/clf-forward-with-different-tags.yaml"
    When I run the :create client command with:
      | f | clf-forward-with-different-tags.yaml |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear
    And default storageclass is stored in the :default_sc clipboard

    Given I obtain test data file "logging/clusterlogging/cl-storage-with-im-template.yaml"
    When I create clusterlogging instance with:
      | crd_yaml            | cl-storage-with-im-template.yaml |
      | storage_class       | <%= cb.default_sc.name %>        |
      | storage_size        | 20Gi                             |
      | es_node_count       | 1                                |
      | redundancy_policy   | ZeroRedundancy                   |
    Then the step should succeed

    # check the .security index is created after ES pods started
    Given I wait for the ".security" index to appear in the ES pod with labels "es-node-master=true"
    And the expression should be true> cb.docs_count > 0
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    Given I wait for the "infra" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    And I wait for the "audit" index to appear in the ES pod with labels "es-node-master=true"

    # store current indices
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cat/indices?format=JSON |
      | op           | GET                      |
    Then the step should succeed
    And evaluation of `@result[:parsed].select {|e| e['index'].start_with? "app"}.map {|x| x["index"]}` is stored in the :app_indices clipboard
    And evaluation of `@result[:parsed].select {|e| e['index'].start_with? "infra"}.map {|x| x["index"]}` is stored in the :infra_indices clipboard
    And evaluation of `@result[:parsed].select {|e| e['index'].start_with? "audit"}.map {|x| x["index"]}` is stored in the :audit_indices clipboard

    # revert the changes
    Given I register clean-up steps:
    """
    Given I use the "openshift-logging" project
    And I successfully merge patch resource "clusterlogging/instance" with:
      | {"spec": {"logStore": {"retentionPolicy": {"application": {"maxAge": "60h"}, "audit": {"maxAge": "3h"}, "infra": {"maxAge": "1d"}}}}} |
    """
    # for testing purpose, update the schedule of cronjobs and maxAge of each log types
    Given I successfully merge patch resource "clusterlogging/instance" with:
      | {"spec": {"logStore": {"retentionPolicy": {"application": {"maxAge": "6m"}, "audit": {"maxAge": "6m"}, "infra": {"maxAge": "6m"}}}}} |
    And I wait up to 60 seconds for the steps to pass:
    """
    Given the expression should be true> elasticsearch("elasticsearch").delete_min_age(cached: false, name: "app-policy") == "6m"
    And the expression should be true> elasticsearch("elasticsearch").delete_min_age(name: "infra-policy") == "6m"
    And the expression should be true> elasticsearch("elasticsearch").delete_min_age(name: "audit-policy") == "6m"
    """
    # revert the changes
    Given I register clean-up steps:
    """
    Given I use the "openshift-logging" project
    And I successfully merge patch resource "elasticsearch/elasticsearch" with:
      | {"spec": {"managementState": "Managed"}} |
    """
    Given I successfully merge patch resource "elasticsearch/elasticsearch" with:
      | {"spec": {"managementState": "Unmanaged"}} |
    And the expression should be true> elasticsearch("elasticsearch").management_state == "Unmanaged"

    Given evaluation of `["elasticsearch-im-app", "elasticsearch-im-audit", "elasticsearch-im-infra"]` is stored in the :cj_names clipboard
    And I repeat the following steps for each :cj_name in cb.cj_names:
    """
    Given I successfully merge patch resource "cronjob/#{cb.cj_name}" with:
      | {"spec": {"schedule": "*/5 * * * *"}} |
    And the expression should be true> cron_job('#{cb.cj_name}').schedule(cached: false) == "*/5 * * * *"
    """

    # Console Dashboard
    Given I switch to the first user
    And I open admin console in a browser
    When I run the :goto_monitoring_db_cluster_logging web action
    Then the step should succeed
    Given evaluation of `["Elastic Nodes", "Elastic Shards", "Elastic Documents", "Total Index Size on Disk"]` is stored in the :cards clipboard
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the :check_monitoring_dashboard_card web action with:
      | card_name | Elastic Cluster Status |
    Then the step should succeed
    """
    And I repeat the following steps for each :card in cb.cards:
    """
    When I perform the :check_monitoring_dashboard_card web action with:
      | card_name | #{cb.card} |
    Then the step should succeed
    """
    And I close the current browser

    # ES Metrics
    Given I use the "openshift-logging" project
    And I wait for the "monitor-elasticsearch-cluster" service_monitor to appear
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
    Given logging collector name is stored in the :collector_name clipboard
    And I wait for the "<%= cb.collector_name %>" service_monitor to appear
    And the expression should be true> service_monitor("<%= cb.collector_name %>").service_monitor_endpoint_spec(port: "metrics").path == "/metrics"
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                            |
      | query | fluentd_output_status_buffer_queue_length |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['data']['result'][0]['value']
    """

    # Kibana Access
    Given I switch to the second user
    And evaluation of `user.cached_tokens.first` is stored in the :user_token_2 clipboard
    When I login to kibana logging web console
    Then the step should succeed
    And I close the current browser

    # Authorization
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    # cluster-admin user
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?format=JSON |
      | op           | GET                       |
      | token        | <%= cb.user_token_1 %>    |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?format=JSON |
      | op           | GET                     |
      | token        | <%= cb.user_token_1 %>  |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    # normal user
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | app*/_count?format=JSON' -d '{"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
      | op           | GET                                                                                                     |
      | token        | <%= cb.user_token_2 %>                                                                                  |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?format=JSON |
      | op           | GET                       |
      | token        | <%= cb.user_token_2 %>    |
    Then the step should succeed
    And the expression should be true> [401, 403].include? @result[:exitstatus]

    # check if there has new index created and check if the old index could be deleted or not
    # !(cb.new_app_indices - cb.app_indices).empty? ensures there has new index
    # !(cb.app_indices - cb.new_app_indices).empty? ensures some old indices can be deleted
    Given I use the "openshift-logging" project
    And I check the cronjob status
    Then the step should succeed
    Given I wait up to 360 seconds for the steps to pass:
    """
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _cat/indices?format=JSON |
      | op           | GET                      |
    Then the step should succeed
    Given evaluation of `@result[:parsed].select {|e| e['index'].start_with? "app"}.map {|x| x["index"]}` is stored in the :new_app_indices clipboard
    And evaluation of `@result[:parsed].select {|e| e['index'].start_with? "infra"}.map {|x| x["index"]}` is stored in the :new_infra_indices clipboard
    And evaluation of `@result[:parsed].select {|e| e['index'].start_with? "audit"}.map {|x| x["index"]}` is stored in the :new_audit_indices clipboard
    Then the expression should be true> !(cb.new_app_indices - cb.app_indices).empty? && !(cb.app_indices - cb.new_app_indices).empty?
    And the expression should be true> !(cb.new_infra_indices - cb.infra_indices).empty? && !(cb.infra_indices - cb.new_infra_indices).empty?
    And the expression should be true> !(cb.new_audit_indices - cb.audit_indices).empty? && !(cb.audit_indices - cb.new_audit_indices).empty?
    """

    # pod logs in last 5 minutes
    Given I check all pods logs in the "openshift-operators-redhat" project in last 300 seconds
    And I check all pods logs in the "openshift-logging" project in last 300 seconds
