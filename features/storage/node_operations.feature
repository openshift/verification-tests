Feature: Node operations test scenarios

  # @author jhou@redhat.com
  @admin
  @destructive
  @upgrade-sanity
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Drain a node that has cloud vendor volumes
    Given environment has at least 2 schedulable nodes
    And I have a project

    # Create a deployment config
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/hello-openshift@sha256:56c354e7885051b6bb4263f9faa58b2c292d44790599b7dde0e49e7c466cf339 |
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
      | case_id           | cloud_provider |
      | OCP-15287:Storage | gcp            | # @case_id OCP-15287

    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | cloud_provider |
      | OCP-15275:Storage | azure-disk     | # @case_id OCP-15275

    @vsphere-ipi
    @vsphere-upi
    Examples:
      | case_id           | cloud_provider |
      | OCP-15268:Storage | vsphere-volume | # @case_id OCP-15268

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id           | cloud_provider |
      | OCP-15276:Storage | cinder         | # @case_id OCP-15276

    @hypershift-hosted
    @critical
    Examples:
      | case_id           | cloud_provider |
      | OCP-15283:Storage | aws-ebs        | # @case_id OCP-15283
