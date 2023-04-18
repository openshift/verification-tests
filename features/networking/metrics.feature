Feature: SDN/OVN metrics related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-28519
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @connected
  @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-28519:SDN Prometheus should be able to monitor kubeproxy metrics
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    And evaluation of `endpoints('sdn').subsets.first.addresses.first.ip.to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `endpoints('sdn').subsets.first.ports.first.port.to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard

    Given I use the "openshift-monitoring" project
    Given I find a bearer token of the prometheus-k8s service account
    And evaluation of `service_account('prometheus-k8s').cached_tokens.first` is stored in the :sa_token clipboard

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
      | exec_command_arg | <%= cb.curl_query %> |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9101
    And the output should contain:
      | kubeproxy_sync_proxy_rules_duration       |
      | kubeproxy_sync_proxy_rules_last_timestamp |

  # @author anusaxen@redhat.com
  # @case_id OCP-16016
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-16016:SDN Should be able to monitor the openshift-sdn related metrics by prometheus
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sdn" project
    And evaluation of `endpoints('sdn').subsets.first.addresses.first.ip.to_s` is stored in the :metrics_ep_ip clipboard
    And evaluation of `endpoints('sdn').subsets.first.ports.first.port.to_s` is stored in the :metrics_ep_port clipboard
    And evaluation of `cb.metrics_ep_ip + ':' +cb.metrics_ep_port` is stored in the :metrics_ep clipboard

    Given I use the "openshift-monitoring" project
    Given I find a bearer token of the prometheus-k8s service account
    And evaluation of `service_account('prometheus-k8s').cached_tokens.first` is stored in the :sa_token clipboard

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
      | exec_command_arg | <%= cb.curl_query %> |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9101
    And the output should contain:
      | openshift_sdn_arp  |
      | openshift_sdn_pod  |
      | openshift_sdn_vnid |
      | openshift_sdn_ovs  |
  
  # @author anusaxen@redhat.com
  # @case_id OCP-37704
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @network-ovnkubernetes
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-37704:SDN Should be able to monitor various ovnkube-master and ovnkube-node metrics via prometheus
    Given I store kubernetes elected leader pod for ovnkube-master in the :leader_pod clipboard
    And evaluation of `cb.leader_pod.ip` is stored in the :leader_pod_ip clipboard
    And evaluation of `endpoints('ovn-kubernetes-master').subsets.first.ports.first.port.to_s` is stored in the :ovn_master_metrics_ep_port clipboard
    And evaluation of `cb.leader_pod_ip + ':' +cb.ovn_master_metrics_ep_port` is stored in the :ovn_master_metrics_ep clipboard
    
    And evaluation of `endpoints('ovn-kubernetes-node').subsets.first.addresses.first.ip.to_s` is stored in the :ovn_node_metrics_ep_ip clipboard
    And evaluation of `endpoints('ovn-kubernetes-node').subsets.flat_map{ |i| i.ports }.select{ |p| p.name == "metrics" }.first.port.to_s` is stored in the :ovn_node_metrics_ep_port clipboard
    And evaluation of `cb.ovn_node_metrics_ep_ip + ':' +cb.ovn_node_metrics_ep_port` is stored in the :ovn_node_metrics_ep clipboard
    
    Given I use the "openshift-monitoring" project
    Given I find a bearer token of the prometheus-k8s service account
    And evaluation of `service_account('prometheus-k8s').cached_tokens.first` is stored in the :sa_token clipboard

    #Storing respective curl queries in clipboards to be able to call them during execution on prometheus pods
    Given evaluation of `%Q{curl -k -H \"Authorization: Bearer <%= cb.sa_token %>\" https://<%= cb.ovn_master_metrics_ep %>/metrics}` is stored in the :curl_query_for_ovn_master clipboard
    Given evaluation of `%Q{curl -k -H \"Authorization: Bearer <%= cb.sa_token %>\" https://<%= cb.ovn_node_metrics_ep %>/metrics}` is stored in the :curl_query_for_ovn_node clipboard
    When I run the :exec admin command with:
      | n                | openshift-monitoring                |
      | pod              | prometheus-k8s-0                    |
      | c                | prometheus                          |
      | oc_opts_end      |                                     |
      | exec_command     | bash                                |
      | exec_command_arg | -c                                  |
      | exec_command_arg | <%= cb.curl_query_for_ovn_master %> |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9102 for ovnkube-master
    And the output should contain:
      | ovnkube_master_build_info gauge           |
      | ovnkube_master_leader                     |
      | ovnkube_master_nb_e2e_timestamp           |
      | ovnkube_master_pod_creation_latency       |
      | ovnkube_master_ready_duration             |
      | ovnkube_master_sb_e2e_timestamp           |
    
    When I run the :exec admin command with:
      | n                | openshift-monitoring              |
      | pod              | prometheus-k8s-0                  |
      | c                | prometheus                        |
      | oc_opts_end      |                                   |
      | exec_command     | bash                              |
      | exec_command_arg | -c                                |
      | exec_command_arg | <%= cb.curl_query_for_ovn_node %> |
    Then the step should succeed
    #The idea is to check whether these metrics are being relayed on the port 9103 for ovnkube-node
    And the output should contain:
      | ovnkube_node_build_info |
      | ovnkube_node_cni        |
      | ovnkube_node_nodeport   |
      | ovnkube_node_ready      |
