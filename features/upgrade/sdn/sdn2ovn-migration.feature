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
    Given I store the masters in the :masters clipboard
    And the Internal IP of node "<%= cb.masters[0].name %>" is stored in the :master0_ip clipboard
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
