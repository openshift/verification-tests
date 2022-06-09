Feature: cluster logging related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-21311
  @admin
  @destructive
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21311 Deploy Logging Via Community Operators
    Given logging service has been installed successfully

