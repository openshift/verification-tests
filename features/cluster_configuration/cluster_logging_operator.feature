Feature: cluster logging related scenarios
  # @author pruan@redhat.com
  # @case_id OCP-21311
  @admin
  @destructive
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario: Deploy Logging Via Community Operators
    Given logging service has been installed successfully

