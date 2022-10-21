@clusterlogging
Feature: Cases to test forward logs to external elasticsearch

  # @author qitang@redhat.com
  @admin
  @destructive
  @4.7 @4.6
  Scenario Outline: ClusterLogForwarder: Forward logs to non-clusterlogging-managed elasticsearch
    Given I switch to the first user
    And I have a project
    And evaluation of `project` is stored in the :es_proj clipboard
    Given external elasticsearch server is deployed with:
      | version      | 6.8                    |
      | scheme       | <scheme>               |
      | client_auth  | <client_auth>          |
      | project_name | <%= cb.es_proj.name %> |
      | secret_name  | pipelinesecret         |

    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/elasticsearch/<file>"
    When I process and create:
      | f | <file> |
      | p | URL=<scheme>://elasticsearch-server.<%= cb.es_proj.name %>.svc:9200 |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed

    Given I use the "<%= cb.es_proj.name %>" project
    And I wait up to 300 seconds for the steps to pass:
    """
    # check app logs
    When I check in the external ES pod with:
      | project_name | <%= cb.es_proj.name %>   |
      | pod_label    | app=elasticsearch-server |
      | scheme       | <scheme>                 |
      | client_auth  | <client_auth>            |
      | url_path     | */_count?format=JSON     |
      | query        | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check journal logs
    When I check in the external ES pod with:
      | project_name | <%= cb.es_proj.name %>   |
      | pod_label    | app=elasticsearch-server |
      | scheme       | <scheme>                 |
      | client_auth  | <client_auth>            |
      | url_path     | */_count?format=JSON     |
      | query        | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check logs in openshift* namespace
    When I check in the external ES pod with:
      | project_name | <%= cb.es_proj.name %>   |
      | pod_label    | app=elasticsearch-server |
      | scheme       | <scheme>                 |
      | client_auth  | <client_auth>            |
      | url_path     | */_count?format=JSON     |
      | query        | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check audit logs
    When I check in the external ES pod with:
      | project_name | <%= cb.es_proj.name %>   |
      | pod_label    | app=elasticsearch-server |
      | scheme       | <scheme>                 |
      | client_auth  | <client_auth>            |
      | url_path     | */_count?format=JSON     |
      | query        | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    """

    @singlenode
    @vsphere-ipi @openstack-ipi @nutanix-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @network-ovnkubernetes @network-openshiftsdn
    @proxy @noproxy @disconnected @connected
    @arm64 @amd64 @heterogeneous
    Examples:
      | case_id           | scheme | client_auth | file                 |
      | OCP-29845:Logging | https  | true        | clf-with-secret.yaml | # @case_id OCP-29845
      | OCP-29846:Logging | http   | false       | clf-insecure.yaml    | # @case_id OCP-29846

  # @author qitang@redhat.com
  @admin
  @destructive
  Scenario Outline: Forward to external ES with username/password
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :es_proj clipboard
    Given external elasticsearch server is deployed with:
      | version           | <version>         |
      | scheme            | <scheme>          |
      | client_auth       | <client_auth>     |
      | user_auth_enabled | true              |
      | project_name      | <%= cb.es_proj %> |
      | username          | <username>        |
      | password          | <password>        |
      | secret_name       | <secret_name>     |
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given admin ensures "instance" cluster_log_forwarder is deleted from the "openshift-logging" project after scenario
    And I obtain test data file "logging/clusterlogforwarder/elasticsearch/clf-with-secret.yaml"
    When I process and create:
      | f | clf-with-secret.yaml |
      | p | URL=<scheme>://elasticsearch-server.<%= cb.es_proj %>.svc:9200 |
      | p | PIPELINE_SECRET_NAME=<secret_name> |
    Then the step should succeed
    And I wait for the "instance" cluster_log_forwarder to appear

    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true              |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed

    Given I use the "<%= cb.es_proj %>" project
    And a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 300 seconds for the steps to pass:
    """
    # check app logs
    When I check in the external ES pod with:
      | project_name      | <%= cb.es_proj %>        |
      | pod_label         | app=elasticsearch-server |
      | scheme            | <scheme>                 |
      | client_auth       | <client_auth>            |
      | user_auth_enabled | true                     |
      | username          | <username>               |
      | password          | <password>               |
      | url_path          | */_count?format=JSON     |
      | query             | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check journal logs
    When I check in the external ES pod with:
      | project_name      | <%= cb.es_proj %>        |
      | pod_label         | app=elasticsearch-server |
      | scheme            | <scheme>                 |
      | client_auth       | <client_auth>            |
      | user_auth_enabled | true                     |
      | username          | <username>               |
      | password          | <password>               |
      | url_path          | */_count?format=JSON     |
      | query             | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check logs in openshift* namespace
    When I check in the external ES pod with:
      | project_name      | <%= cb.es_proj %>        |
      | pod_label         | app=elasticsearch-server |
      | scheme            | <scheme>                 |
      | client_auth       | <client_auth>            |
      | user_auth_enabled | true                     |
      | username          | <username>               |
      | password          | <password>               |
      | url_path          | */_count?format=JSON     |
      | query             | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0

    # check audit logs
    When I check in the external ES pod with:
      | project_name      | <%= cb.es_proj %>        |
      | pod_label         | app=elasticsearch-server |
      | scheme            | <scheme>                 |
      | client_auth       | <client_auth>            |
      | user_auth_enabled | true                     |
      | username          | <username>               |
      | password          | <password>               |
      | url_path          | */_count?format=JSON     |
      | query             | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    """

    @heterogeneous @arm64 @amd64
    @vsphere-ipi @openstack-ipi @nutanix-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @proxy @noproxy @disconnected @connected
    @network-ovnkubernetes @network-openshiftsdn
    Examples:
      | case_id           | version | scheme | client_auth | username | password | secret_name |
      | OCP-41807:Logging | 7.16    | https  | true        | test1    | redhat   | test1       | # @case_id OCP-41807
      | OCP-41805:Logging | 6.8     | http   | false       | test2    | redhat   | test2       | # @case_id OCP-41805
      | OCP-41806:Logging | 6.8     | https  | false       | test4    | redhat   | test4       | # @case_id OCP-41806
