Feature: CloudCredentialOperator components upgrade tests
  # @author lwan@redhat.com
  @upgrade-prepare
  @admin
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Cluster operator cloud-credential should be available after upgrade - prepare
    #Check cloud-credential version
    Given the "cloud-credential" operator version matches the current cluster version
    # Check cluster operator cloud-credential should be in correct status
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Degraded')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Upgradeable')['status'] == "True"

  # @author lwan@redhat.com
  # @case_id OCP-34260
  @upgrade-check
  @admin
  @4.7 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  Scenario: Cluster operator cloud-credential should be available after upgrade
    # Check cloud-credential operator version after upgraded
    Given the "cloud-credential" operator version matches the current cluster version
    # Check cluster operator cloud-credential should be in correct status
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Degraded')['status'] == "False"
