Feature: CloudCredentialOperator components upgrade tests
  # @author lwan@redhat.com
  @upgrade-prepare
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  Scenario: Cluster operator cloud-credential should be available after upgrade - prepare
    Given I switch to cluster admin pseudo user
    #Check cloud-credential version
    Given the "cloud-credential" operator version matches the current cluster version
    #Check cluster operator cloud-credential should be in correct status
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Degraded')['status'] == "False"
    Given I run the :get client command with:
      | resource      | cloudcredential           |
      | resource_name | cluster                   |
      | template      | {{.spec.credentialsMode}} |
    And evaluation of `@result[:stdout]` is stored in the :cco_mode clipboard
    #Upgradeable status supported from 4.2
    #Upgradeable default false if cco in Manual mode from 4.8
    Then the expression should be true> env.version_le("4.1", user: user) ? true : cluster_operator('cloud-credential').condition(type: 'Upgradeable')['status'] == (env.version_ge("4.8", user: user) && "<%= cb.cco_mode %>" == "Manual" ? "False" : "True")

  # @author lwan@redhat.com
  # @case_id OCP-34260
  @upgrade-check
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Cluster operator cloud-credential should be available after upgrade
    # Check cloud-credential operator version after upgraded
    Given the "cloud-credential" operator version matches the current cluster version
    # Check cluster operator cloud-credential should be in correct status
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Degraded')['status'] == "False"
