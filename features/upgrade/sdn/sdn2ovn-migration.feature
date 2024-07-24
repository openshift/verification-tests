Feature: sdn2ovn migration testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @4.13 @4.12
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @upgrade
  @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: sdn2ovn migration support custom OVNKube joint network CIDR - prepare before migration 
    Given the plugin is openshift-ovs-networkpolicy on the cluster
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"v4InternalSubnet":"100.66.0.0/16" }}}} |
    Given the OVN joint network CIDR is patched in the node
    
  # @author weliang@redhat.com
  # @case_id OCP-54166
  @admin
  @upgrade-check
  @network-ovnkubernetes
  @4.13 @4.12
  @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @proxy @noproxy @disconnected @connected
  Scenario: sdn2ovn migration support custom OVNKube joint network CIDR - check after migration
  Given the cluster is migrated from sdn
  Given I store the masters in the :masters clipboard
  When I run the :get admin command with:
    | resource      | node                                                                          |
    | resource_name | <%= cb.masters[0].name %>                                                     |
    | o             | jsonpath={.metadata.annotations.k8s\.ovn\.org/node-gateway-router-lrp-ifaddr} |
  Then the step should succeed
  Then the outputs should contain "{"ipv4":"100.66.0."

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @vsphere-ipi
  @vsphere-upi
  @upgrade
  @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @4.16 @4.15 @4.14 @4.13 @4.12
  Scenario: Check sdn2ovn egressip is functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given the env is using "OpenShiftSDN" networkType
    Given I save ipecho url to the clipboard
    Given I store the schedulable workers in the :workers clipboard
    Given I store a random unused IP address from the reserved range to the clipboard
    And evaluation of `lambda { |i| "#{i.to_s}/#{i.prefix.to_s}" }.call(IPAddr.new("<%= cb.subnet_range %>"))` is stored in the :valid_subnet clipboard
    #Patch two egress CIDRs to two nodes
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.workers[0].name %>" with:
      | {"egressCIDRs": ["<%= cb.valid_subnet %>"] }   |
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.workers[1].name %>" with:
      | {"egressCIDRs": ["<%= cb.valid_subnet %>"] }   |
    #Create two projects and pods
    When I run the :new_project client command with:
      | project_name | sdn2ovn-egressip-upgrade1 |
    Then the step should succeed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    When I use the "sdn2ovn-egressip-upgrade1" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard
    When I run the :new_project client command with:
      | project_name | sdn2ovn-egressip-upgrade2 |
    Then the step should succeed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    When I use the "sdn2ovn-egressip-upgrade2" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(2).name` is stored in the :pod2 clipboard
    #Patch an egressip on each project
    Given as admin I successfully merge patch resource "netnamespace/sdn2ovn-egressip-upgrade1" with:
      | {"egressIPs": ["<%= cb.valid_ips[0] %>"]} |
    Given as admin I successfully merge patch resource "netnamespace/sdn2ovn-egressip-upgrade2" with:
      | {"egressIPs": ["<%= cb.valid_ips[1] %>"]} |
    #Check the source ip
    And I wait up to 30 seconds for the steps to pass:
    """
    When I use the "sdn2ovn-egressip-upgrade2" project
    And I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ips[1] %>"
    When I use the "sdn2ovn-egressip-upgrade1" project
    And I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ips[0] %>"
    """

  # @author weliang@redhat.com
  # @case_id OCP-54552
  @admin
  @upgrade-check
  @4.16 @4.15 @4.14 @4.13 @4.12
  @vsphere-ipi
  @vsphere-upi
  @upgrade
  @network-ovnkubernetes
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: Check sdn2ovn egressip is functional post upgrade
  Given I switch to cluster admin pseudo user
  Given the cluster is migrated from sdn
  Given I save ipecho url to the clipboard
  
  #Get configured EgressIPs
  When I run the :get admin command with:
    | resource       | egressip                           |
    | resource_name  | egressip-sdn2ovn-egressip-upgrade1 |
    | o              | jsonpath={.status.items[*]}        |
  Then the step should succeed
  And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)` is stored in the :egress_ip1 clipboard
  When I run the :get admin command with:
    | resource       | egressip                           |
    | resource_name  | egressip-sdn2ovn-egressip-upgrade2 |
    | o              | jsonpath={.status.items[*]}        |
  Then the step should succeed
  And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)` is stored in the :egress_ip2 clipboard
  When I use the "sdn2ovn-egressip-upgrade1" project
  Given status becomes :running of 1 pod labeled:
    | name=test-pods |
  And evaluation of `pod(0).name` is stored in the :pod1 clipboard
  And I execute on the "<%= cb.pod1 %>" pod:
    | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
  Then the step should succeed
  And the output should contain "<%= cb.egress_ip1 %>"
  When I use the "sdn2ovn-egressip-upgrade2" project
  Given status becomes :running of 1 pod labeled:
    | name=test-pods |
  And evaluation of `pod(1).name` is stored in the :pod2 clipboard
  And I execute on the "<%= cb.pod2 %>" pod:
    | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
  Then the step should succeed
  And the output should contain "<%= cb.egress_ip2 %>"
  
  # Remove label from egressip node and delete egress ip object
  Given admin ensures "egressip" egress_ip is deleted after scenario
  When I run the :get admin command with:
    | resource       | node                               |
    | l              | k8s.ovn.org/egress-assignable      |
    | o              | jsonpath={.items[*].metadata.name} |
  Then the step should succeed
  And evaluation of `@result[:response].split(" ")` is stored in the :egress_node clipboard
  When I run the :label admin command with:
    | resource | node                               |
    | name     | <%= cb.egress_node[0] %>           |
    | key_val  | k8s.ovn.org/egress-assignable-     |
  Then the step should succeed
    When I run the :label admin command with:
    | resource | node                               |
    | name     | <%= cb.egress_node[1] %>           |
    | key_val  | k8s.ovn.org/egress-assignable-     |
  Then the step should succeed
