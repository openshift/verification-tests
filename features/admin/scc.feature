Feature: SCC policy related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-11762
  @admin
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: deployment hook volume inheritance with hostPath volume
    Given I have a project
    # Create hostdir pod again with new SCC
    Given I obtain test data file "authorization/scc/ocp11762/scc_hostdir.yaml"
    When I run the :create admin command with:
      | f | scc_hostdir.yaml |
    Then the step should succeed
    Given I obtain test data file "authorization/scc/ocp11762/dc.json"
    When I run the :create client command with:
      | f | dc.json |
    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | scc         |
      | object_name_or_id | scc-hostdir |
    the step should succeed
    """
    And the pod named "hooks-1-deploy" status becomes :running
    And the pod named "hooks-1-hook-pre" status becomes :running
    # step 2, check the pre-hook pod
    When I get project pod named "hooks-1-hook-pre" as YAML
    Then the step should succeed
    And the expression should be true> @result[:parsed]['spec']['volumes'].any? {|p| p['name'] == "data"} && @result[:parsed]['spec']['volumes'].any? {|p| p['hostPath']['path'] == "/usr"}

  # @author yinzhou@redhat.com
  # @case_id OCP-11775
  @admin
  @destructive
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Create or update scc with illegal capability name should fail with prompt message
    Given I have a project
    Given cluster role "cluster-admin" is added to the "first" user
    Given admin ensures "scc-<%= project.name %>" scc is deleted after scenario
    Given I obtain test data file "authorization/scc/scc_capabilities.yaml"
    When I run oc create over "scc_capabilities.yaml" replacing paths:
      | ["metadata"]["name"]            | scc-<%= project.name %> |
      | ["defaultAddCapabilities"][0]   | BLOCK_SUSPEND           |
      | ["requiredDropCapabilities"][0] | BLOCK_SUSPEND           |
    Then the step should fail
    And the output should contain "capability is listed in defaultAddCapabilities and requiredDropCapabilities"
    Given I obtain test data file "authorization/scc/scc_capabilities.yaml"
    When I run oc create over "scc_capabilities.yaml" replacing paths:
      | ["metadata"]["name"]            | scc-<%= project.name %> |
      | ["allowedCapabilities"][0]      | BLOCK_SUSPEND           |
      | ["requiredDropCapabilities"][0] | BLOCK_SUSPEND           |
    Then the step should fail
    And the output should contain "capability is listed in allowedCapabilities and requiredDropCapabilities"
    Given I obtain test data file "authorization/scc/scc_capabilities.yaml"
    When I run oc create over "scc_capabilities.yaml" replacing paths:
      | ["metadata"]["name"]       | scc-<%= project.name %>                    |
      | ["groups"][0]              | system:serviceaccounts:<%= project.name %> |
      | ["allowedCapabilities"][1] | KILLtest                                   |
    Then the step should succeed
    Given I obtain test data file "authorization/scc/pod_requests_cap_chown.json"
    When I run oc create over "pod_requests_cap_chown.json" replacing paths:
      | ["spec"]["containers"][0]["securityContext"]["capabilities"]["add"][0] | KILLtest |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When  I run the :describe client command with:
      | resource | pod           |
      | name     | pod-add-chown |
    Then the output should match:
      | [uU]nknown\|invalid capability[ .*to add]? |
      | (?i)CAP_KILLtest                           |
    """

