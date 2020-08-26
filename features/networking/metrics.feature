Feature: SDN/OVN metrics related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-28519
  @admin
  Scenario: Prometheus should be able to monitor kubeproxy metrics
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    When I run the :get client command with:
      | resource | ep            |
      | n        | openshift-sdn |
      | o        | json          |
    And evaluation of `@result[:parsed]['items'][0]['subsets'][0]['addresses'][1]['ip'].to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `@result[:parsed]['items'][0]['subsets'][0]['ports'][0]['port'].to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard
    Given I use the "openshift-monitoring" project
    When I run the :exec admin command with:
      | n                | openshift-monitoring                |
      | pod              | prometheus-k8s-0                    |
      | c                | prometheus                          |
      | oc_opts_end      |                                     |
      | exec_command     | curl                                |
      | exec_command_arg | -k                                  |
      | exec_command_arg | http://<%= cb.metrics_ep %>/metrics |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9101
    And the output should contain:
      | kubeproxy_sync_proxy_rules_duration       |
      | kubeproxy_sync_proxy_rules_last_timestamp |

  # @author anusaxen@redhat.com
  # @case_id OCP-16016
  @admin
  Scenario: Should be able to monitor the openshift-sdn related metrics by prometheus
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    When I run the :get client command with:
      | resource | ep            |
      | n        | openshift-sdn |
      | o        | json          |
    And evaluation of `@result[:parsed]['items'][0]['subsets'][0]['addresses'][1]['ip'].to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `@result[:parsed]['items'][0]['subsets'][0]['ports'][0]['port'].to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard
    Given I use the "openshift-monitoring" project
    When I run the :exec admin command with:
      | n                | openshift-monitoring                |
      | pod              | prometheus-k8s-0                    |
      | c                | prometheus                          |
      | oc_opts_end      |                                     |
      | exec_command     | curl                                |
      | exec_command_arg | -k                                  |
      | exec_command_arg | http://<%= cb.metrics_ep %>/metrics |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9101
    And the output should contain:
      | openshift_sdn_pod |
      | openshift_sdn_arp |
      | openshift_sdn_ovs |
