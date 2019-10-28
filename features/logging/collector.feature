@clusterlogging
Feature: collector related tests

  # @auther qitang@redhat.com
  # @case_id OCP-24837
  @admin
  @destructive
  @commonlogging
  Scenario: All nodes logs had sent logs to Elasticsearch
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    # get node ip
    #Given <%= daemon_set("fluentd").replica_counters[:desired] %> pods become ready with labels:
    #  | component=fluentd |
    And evaluation of `@pods.map {|n| n.node_ip}.uniq` is stored in the :node_ips clipboard
    #Given I store the schedulable nodes in the :nodes clipboard
    #And evaluation of `cb.nodes.map {|n| n.name}` is stored in the :node_name clipboard

    And I wait for the ".operations" index to appear in the ES pod with labels "es-node-master=true"
    Given I get the ".operations" logging index information from a pod with labels "es-node-master=true"
    And the expression should be true> cb.index_data['docs.count'] > "0"
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -H 'Content-Type: application/json' -d'{"aggs" : {"exists_field_kubernetes" : {"filter": {"exists": {"field":"kubernetes"}},"aggs" : {"distinct_hostname_name" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET                                                                                                                                                                                                                     |
    Then the step should succeed
    # need to check all the nodes, but how to ?
    Given I repeat the following steps for each :ip in cb.node_ips:
    """
    And the expression should be true> @result[:response].include? cb.ip
    """

    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | _search?pretty&size=0' -H 'Content-Type: application/json' -d'{"aggs" : {"exists_field_kubernetes" : {"filter": {"exists": {"field":"systemd"}},"aggs" : {"distinct_hostname_name" : {"terms" : {"field" : "pipeline_metadata.collector.ipaddr4"}}}}}} |
      | op           | GET                                                                                                                                                                                                                     |
    Then the step should succeed
    Given I repeat the following steps for each :ip in cb.node_ips:
    """
    And the expression should be true> @result[:response].include? cb.ip
    """
