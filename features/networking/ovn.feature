Feature: OVN related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-32205
  @admin
  Scenario: Thrashing ovnkube master IPAM allocator by creating and deleting various pods on a specific node
    Given the env is using "OVNKubernetes" networkType
    And I store all worker nodes to the :nodes clipboard
    And I have a project
    Given I obtain test data file "networking/generic_test_pod_with_replica.yaml"
    When I run the steps 10 times:
    """
    When I run oc create over "generic_test_pod_with_replica.yaml" replacing paths:
      | ["spec"]["replicas"]                     | 25                      |
      | ["spec"]["template"]["spec"]["nodeName"] | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And 25 pods become ready with labels:
      | name=test-pods |
    Given I run the :delete client command with:
      | object_type       | rc      |
      | object_name_or_id | test-rc |
    Then the step should succeed
    And all existing pods die with labels:
      | name=test-pods |
    """
