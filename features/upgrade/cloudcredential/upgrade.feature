Feature: CloudCredentialOperator components upgrade tests
  # @author lwan@redhat.com
  @upgrade-prepare
  @admin
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
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Cluster operator cloud-credential should be available after upgrade
    # Check cloud-credential operator version after upgraded
    Given the "cloud-credential" operator version matches the current cluster version
    # Check cluster operator cloud-credential should be in correct status
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('cloud-credential').condition(type: 'Degraded')['status'] == "False"
