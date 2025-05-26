Feature: Logging smoke test case

  # @author gkarager@redhat.com
  # @case_id OCP-37508
  @flaky
  @admin
  @serial
  @console
  @rosa
  @aro
  @osd_ccs
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
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
    And evaluation of `pod.node_name` is stored in the :node clipboard

    Given I switch to cluster admin pseudo user
    Given I register clean-up steps:
    """
    When I run the :debug admin command with:
      | resource     | node/<%= cb.node %> |
      | oc_opts_end  |                     |
      | exec_command | chroot              |
      | exec_command | /host               |
      | exec_command | auditctl            |
      | exec_command | -W                  |
      | exec_command | /var/log/pods/      |
      | exec_command | -p                  |
      | exec_command | rwa                 |
      | exec_command | -k                  |
      | exec_command | read-write-pod-logs |
    Then the step should succeed
    """

    When I run the :debug admin command with:
      | resource     | node/<%= cb.node %> |
      | oc_opts_end  |                     |
      | exec_command | chroot              |
      | exec_command | /host               |
      | exec_command | auditctl            |
      | exec_command | -w                  |
      | exec_command | /var/log/pods/      |
      | exec_command | -p                  |
      | exec_command | rwa                 |
      | exec_command | -k                  |
      | exec_command | read-write-pod-logs |
    Then the step should succeed

    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/clf-forward-with-different-tags.yaml"
    When I run the :create client command with:
      | f | clf-forward-with-different-tags.yaml |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear
    And I get storageclass from cluster and store it in the :default_sc clipboard

    Given the correct directory name of clusterlogging file is stored in the :cl_dir clipboard
    And I obtain test data file "logging/clusterlogging/<%= cb.cl_dir %>/cl-storage-with-im-template.yaml"
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
    When I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | infra*/_count?pretty'  -d '{"query": {"exists": {"field": "systemd"}}} |
      | op           | GET                                                                     |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['count'] > 0

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

    Given I switch to the first user
    Given the first user is cluster-admin
    And evaluation of `user.cached_tokens.first` is stored in the :user_token_1 clipboard

    Given I switch to the second user
    And evaluation of `user.cached_tokens.first` is stored in the :user_token_2 clipboard

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

    Given I wait up to 180 seconds for the steps to pass:
    """
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
    """

    # Kibana Access
    Given I switch to the second user
    When I login to kibana logging web console
    Then the step should succeed
    And I close the current browser

    # pod logs in last 2 minutes
    Given I check all pods logs in the "openshift-operators-redhat" project in last 120 seconds
    And I check all pods logs in the "openshift-logging" project in last 120 seconds
