Feature: SDN/OVN metrics related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-28519
  @admin
  Scenario: Prometheus should be able to monitor kubeproxy metrics
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    Given evaluation of `env.version_le("4.5", user: user) ? "sdn" : "sdn-metrics"` is stored in the :sdn_label clipboard
    And evaluation of `endpoints(cb.sdn_label).subsets.first.addresses.first.ip.to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `endpoints(cb.sdn_label).subsets.first.ports.first.port.to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard
     
    Given I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :sa_token clipboard

    #Running curl -k http://<%= cb.metrics_ep %>/metrics if version is < 4.6
    #Running curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://<%= cb.metrics_ep %>/metrics if version is > 4.5 as sdn mmetrics should be using https scheme
    Given evaluation of `%Q{curl -k http://<%= cb.metrics_ep %>/metrics}` is stored in the :curl_query_le_4_5 clipboard
    Given evaluation of `%Q{curl -k -H \"Authorization: Bearer <%= cb.sa_token %>\" https://<%= cb.metrics_ep %>/metrics}` is stored in the :curl_query_ge_4_6 clipboard
    Given evaluation of `env.version_le("4.5", user: user) ? "#{cb.curl_query_le_4_5}" : "#{cb.curl_query_ge_4_6}"` is stored in the :curl_query clipboard
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | bash                 |
      | exec_command_arg | -c                   |
      | exec_command     | <%= cb.curl_query %> |
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
    Given evaluation of `env.version_le("4.5", user: user) ? "sdn" : "sdn-metrics"` is stored in the :sdn_label clipboard
    And evaluation of `endpoints(cb.sdn_label).subsets.first.addresses.first.ip.to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `endpoints(cb.sdn_label).subsets.first.ports.first.port.to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard
    
    Given I use the "openshift-monitoring" project
    And evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :sa_token clipboard
    
    #Running curl -k http://<%= cb.metrics_ep %>/metrics if version is < 4.6
    #Running curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://<%= cb.metrics_ep %>/metrics if version is > 4.5 as sdn metrics should be using https scheme
    Given evaluation of `%Q{curl -k http://<%= cb.metrics_ep %>/metrics}` is stored in the :curl_query_le_4_5 clipboard
    Given evaluation of `%Q{curl -k -H \"Authorization: Bearer <%= cb.sa_token %>\" https://<%= cb.metrics_ep %>/metrics}` is stored in the :curl_query_ge_4_6 clipboard
    Given evaluation of `env.version_le("4.5", user: user) ? "#{cb.curl_query_le_4_5}" : "#{cb.curl_query_ge_4_6}"` is stored in the :curl_query clipboard
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | bash                 |
      | exec_command_arg | -c                   |
      | exec_command     | <%= cb.curl_query %> |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9101
    And the output should contain:
      | kubeproxy_sync_proxy_rules_duration       |
      | kubeproxy_sync_proxy_rules_last_timestamp |
