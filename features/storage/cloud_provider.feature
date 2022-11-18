Feature: kubelet restart and node restart

  # @author lxia@redhat.com
  @admin
  @destructive
  @inactive
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: kubelet restart should not affect attached/mounted volumes
    Given I have a project
    When I run the :new_app client command with:
      | template | mysql-persistent |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=mysql |

    When I execute on the pod:
      | touch | /var/lib/mysql/data/testfile_before_restart |
    Then the step should succeed
    # restart kubelet on the node
    Given I use the "<%= pod.node_name %>" node
    And the node service is restarted on the host
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | ls | /var/lib/mysql/data/testfile_before_restart |
    Then the step should succeed
    When I execute on the pod:
      | touch | /var/lib/mysql/data/testfile_after_restart |
    Then the step should succeed
    """

    @azure-ipi
    @azure-upi
    Examples:
      | case_id           | platform   |
      | OCP-13333:Storage | azure-disk | # @case_id OCP-13333

    @openstack-ipi
    @openstack-upi
    Examples:
      | case_id           | platform |
      | OCP-11317:Storage | cinder   | # @case_id OCP-11317

    @gcp-ipi
    @gcp-upi
    Examples:
      | case_id           | platform |
      | OCP-11613:Storage | gce      | # @case_id OCP-11613

    @vsphere-ipi
    @vsphere-upi
    @hypershift-hosted
    Examples:
      | case_id           | platform       |
      | OCP-13631:Storage | vsphere-volume | # @case_id OCP-13631
