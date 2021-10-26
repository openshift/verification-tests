Feature: Node operations test scenarios

  # @author jhou@redhat.com
  @admin
  @destructive
  @4.10 @4.9
  Scenario Outline: Drain a node that has cloud vendor volumes
    Given environment has at least 2 schedulable nodes
    And I have a project

    # Create a deployment config
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/storage@sha256:a05b96d373be86f46e76817487027a7f5b8b5f87c0ac18a246b018df11529b40 |
      | labels       | name=jenkins                                                                                          |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins |

    # Restore schedulable node
    Given node schedulable status should be restored after scenario
    When I run the :oadm_drain admin command with:
      | node_name         | <%= pod.node_name %> |
      | delete-local-data | true                 |
      | ignore-daemonsets | true                 |
      | force             | true                 |
    Then the step should succeed

    # Verify old pod is deleted
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear

    When I run the :oadm_uncordon_node admin command with:
      | node_name | <%= pod.node_name %> |
    Then the step should succeed
    # After draining, new Pod becomes available
    And a pod becomes ready with labels:
      | name=jenkins |

    @gcp-ipi
    @gcp-upi
    Examples:
      | cloud_provider |
      | gcp            | # @case_id OCP-15287

    @azure-ipi
    @azure-upi
    Examples:
      | cloud_provider |
      | azure-disk     | # @case_id OCP-15275

    @vsphere-ipi
    @vsphere-upi
    Examples:
      | cloud_provider |
      | vsphere-volume | # @case_id OCP-15268

    @openstack-ipi
    @openstack-upi
    Examples:
      | cloud_provider |
      | cinder         | # @case_id OCP-15276

    Examples:
      | cloud_provider |
      | aws-ebs        | # @case_id OCP-15283
