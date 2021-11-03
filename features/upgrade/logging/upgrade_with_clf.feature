Feature: Upgrade Logging with ClusterLogForwarder

  # @author qitang@redhat.com
  @admin
  @destructive
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: Upgrade clusterlogging with mulitple external log store enabled - prepare
    Given the master version >= "4.6"
    And logging operators are installed successfully
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | logging-receivers |
    Then the step should succeed
    Given fluentd receiver is deployed as insecure in the "logging-receivers" project
    And rsyslog receiver is deployed as insecure in the "logging-receivers" project
    And external elasticsearch server is deployed with:
      | version               | 6.8               |
      | scheme                | http              |
      | transport_ssl_enabled | false             |
      | project_name          | logging-receivers |
    When I run the :new_project client command with:
      | project_name | logging-data |
    Then the step should succeed
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I obtain test data file "logging/clusterlogforwarder/clf-multiple-external-logstore-template.yaml"
    When I process and create:
      | f | clf-multiple-external-logstore-template.yaml                             |
      | p | FLUENTD_URL=udp://fluentdserver.logging-receivers.svc:24224              |
      | p | SYSLOG_URL=tcp://rsyslogserver.logging-receivers.svc:514                 |
      | p | ELASTICSEARCH_URL=http://elasticsearch-server.logging-receivers.svc:9200 |
    Then the step should succeed
    Given I obtain test data file "logging/clusterlogging/fluentd_only.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | false             |
      | crd_yaml            | fluentd_only.yaml |
    Then the step should succeed
    #check data in fluentd server
    Given I use the "logging-receivers" project
    And a pod becomes ready with labels:
      | component=fluentdserver |
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log |
    And the output should not contain:
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    # check data in rsyslog server
    Given a pod becomes ready with labels:
      | component=rsyslogserver |
    And I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /var/log/clf/ |
    Then the output should contain:
      | audit.log |
    And the output should not contain:
      | app-container.log   |
      | infra.log           |
      | infra-container.log |
    """
    # check data in elasticsearch server
    Given a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 300 seconds for the steps to pass:
    """
    # check journal logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check logs in openshift* namespace
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check audit logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    # check app logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "logging-data"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    """


  # @case_id OCP-29743
  # @author qitang@redhat.com
  @admin
  @destructive
  @upgrade-check
  @users=upuser1,upuser2
  @stage-only
  Scenario: Upgrade clusterlogging with mulitple external log store enabled
    Given the master version >= "4.6"
    #check data
    Given I switch to cluster admin pseudo user
    And I use the "logging-receivers" project
    #check data in fluentd server
    And a pod becomes ready with labels:
      | component=fluentdserver |
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log |
    And the output should not contain:
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    # check data in rsyslog server
    Given a pod becomes ready with labels:
      | component=rsyslogserver |
    And I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /var/log/clf/ |
    Then the output should contain:
      | audit.log |
    And the output should not contain:
      | app-container.log   |
      | infra.log           |
      | infra-container.log |
    """
    # check data in elasticsearch server
    Given a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 300 seconds for the steps to pass:
    """
    # check journal logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check logs in openshift* namespace
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check audit logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    # check app logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "logging-data"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    """

    # upgrade CLO and EO if needed
    Given I make sure the logging operators match the cluster version

    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj_au clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed

    # check data again
    Given I switch to cluster admin pseudo user
    Given I use the "logging-receivers" project
    When I run the :delete client command with:
      | object_type | pod  |
      | all         | true |
    Then the step should succeed
    #check data in fluentd server
    Given a pod becomes ready with labels:
      | component=fluentdserver |
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /fluentd/log |
    Then the output should contain:
      | app.log |
    And the output should not contain:
      | audit.log           |
      | infra.log           |
      | infra-container.log |
    """
    # check data in rsyslog server
    Given a pod becomes ready with labels:
      | component=rsyslogserver |
    And I wait up to 300 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | -l | /var/log/clf/ |
    Then the output should contain:
      | audit.log |
    And the output should not contain:
      | app-container.log   |
      | infra.log           |
      | infra-container.log |
    """
    # check data in elasticsearch server
    Given a pod becomes ready with labels:
      | app=elasticsearch-server |
    And I wait up to 300 seconds for the steps to pass:
    """
    # check journal logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "systemd"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check logs in openshift* namespace
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"regexp": {"kubernetes.namespace_name": "openshift@"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] > 0
    # check audit logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"exists": {"field": "auditID"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    # check app logs
    When I execute on the pod:
      | curl | -sk | -XGET | http://localhost:9200/*/_count?format=JSON | -H | Content-Type: application/json | -d | {"query": {"match": {"kubernetes.namespace_name": "<%= cb.proj_au.name %>"}}} |
    Then the step should succeed
    And the expression should be true> JSON.parse(@result[:stdout])['count'] = 0
    """
