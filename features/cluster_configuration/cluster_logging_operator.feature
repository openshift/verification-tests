Feature: cluster logging related scenarios
  # @author pruan@redhat.com
  # @case_id OCP-21311
  @admin
  @destructive
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Deploy Logging Via Community Operators
    Given logging service has been installed successfully

