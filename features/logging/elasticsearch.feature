Feature: elasticsearch related tests

  # @author pruan@redhat.com
  # @case_id OCP-16688
  @admin
  @destructive
  Scenario: OCP-16688 The journald log can be retrived from elasticsearch
    Given I create a project with non-leading digit name
    And logging service is installed in the system
    And I run commands on the host:
      | logger --tag deadbeef[123] deadbeef-message-OCP16688 |
    Then the step should succeed
    ### hack alert with 3.9, I get inconsistent behavior such that the data is
    # not pushed w/o removing the  es-containers.log.pos journal.pos files
    And I run commands on the host:
      | rm -f /var/log/journal.pos         |
      | rm -f /var/log/es-containers-*.pos |
    Then the step should succeed
    And I wait up to 600 seconds for the steps to pass:
    """
    And I perform the HTTP request on the ES pod:
      | relative_url | _search?pretty&size=5&q=message:deadbeef-message-OCP16688 |
      | op           | GET                                                       |

    And the expression should be true> @result[:parsed]['hits']['hits'][0]['_source']['message'] == 'deadbeef-message-OCP16688'
    """
    And evaluation of `@result[:parsed]['hits']['hits'][0]['_source']` is stored in the :query_res clipboard
    Then the expression should be true> (["hostname", "@timestamp"] - cb.query_res.keys).empty?
    # check for SYSLOG, SYSLOG_IDENTIFIER
    Then the expression should be true> (["SYSLOG_FACILITY", "SYSLOG_IDENTIFIER", "SYSLOG_PID"] - cb.query_res['systemd']['u'].keys).empty?
    And the expression should be true> cb.query_res['systemd']['u']['SYSLOG_IDENTIFIER'] == 'deadbeef'
    And the expression should be true> cb.query_res['systemd']['u']['SYSLOG_PID'] == '123'

  # @author pruan@redhat.com
  # @case_id OCP-11266
  @admin
  @destructive
  Scenario: OCP-11266 Use index names of project_name.project_uuid.xxx in Elasticsearch
    Given the master version < "3.4"
    Given I create a project with non-leading digit name
    And logging service is installed in the system
    And a pod becomes ready with labels:
      | component=es |
    # index takes over 10 minutes to come up initially
    And I wait up to 900 seconds for the steps to pass:
    """
    And I execute on the pod:
      | bash                                                                    |
      | -c                                                                      |
      | ls /elasticsearch/persistent/logging-es/data/logging-es/nodes/0/indices |
    And the output should contain:
      | <%= project.name %>.<%= project.uid %> |
    """

