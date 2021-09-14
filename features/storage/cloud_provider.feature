Feature: kubelet restart and node restart

  # @author lxia@redhat.com
  @admin
  @destructive
  @inactive
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

    Examples:
      | platform       |
      | azure-disk     | # @case_id OCP-13333
      | cinder         | # @case_id OCP-11317
      | gce            | # @case_id OCP-11613
      | vsphere-volume | # @case_id OCP-13631
