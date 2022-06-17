Feature: Node management

  # @author chaoyang@redhat.com
  # @case_id OCP-11084
  @admin
  Scenario: OCP-11084 admin can get nodes
    Given I have a project
    When I run the :get admin command with:
      |resource|nodes|
    Then the step should succeed
    Then the outputs should contain "Ready"

  # @author qwang@redhat.com
  # @case_id OCP-15111
  @admin
  @destructive
  Scenario: OCP-15111 Pod will be OOMKilled when memory request is more than node allocatable
    Given I have a project
    # Make sure when there are multi-node, you just modify one and schedule pods here
    Given I store the schedulable nodes in the :nodes clipboard
    Given the taints of the nodes in the clipboard are restored after scenario
    When I run the :oadm_taint_nodes admin command with:
      | node_name | noescape: <%= cb.nodes.map(&:name).join(" ") %> |
      | key_val   | size=large:NoSchedule                           |
    Then the step should succeed
    When I run the :oadm_taint_nodes admin command with:
      | node_name | <%= cb.nodes[0].name %> |
      | key_val   | size-                   |
    Then the step should succeed
    Given I use the "<%= cb.nodes[0].name %>" node
    And evaluation of `cb.nodes[0].capacity_cpu(user: admin)` is stored in the :node_capacity_cpu clipboard
    And evaluation of `cb.nodes[0].capacity_memory` is stored in the :node_capacity_memory clipboard
    And evaluation of `cb.nodes[0].allocatable_cpu` is stored in the :node_allocate_cpu clipboard
    And evaluation of `cb.nodes[0].allocatable_memory` is stored in the :node_allocate_memory clipboard
    Given node config is merged with the following hash:
    """
    kubeletArguments:
      cgroups-per-qos:
      - "true"
      cgroup-driver:
      - "systemd"
      enforce-node-allocatable:
      - "pods"
      kube-reserved:
      - "cpu=100m,memory=600Mi"
      system-reserved:
      - "cpu=200m,memory=800Mi"
    """
    When I try to restart the node service on node
    Then the step should succeed
    And the expression should be true> cb.nodes[0].capacity_cpu(user: admin, cached: false) == <%= cb.node_capacity_cpu %>
    And the expression should be true> cb.nodes[0].capacity_memory == <%= cb.node_capacity_memory %>
    And the expression should be true> cb.nodes[0].allocatable_cpu == <%= cb.node_allocate_cpu %> - 300
    And the expression should be true> cb.nodes[0].allocatable_memory == <%= cb.node_allocate_memory %> - 1400 * 1024 * 1024
    # Consume less than node allocatable memory, stress --vm 1 --vm-bytes <%= cb.node_allocate_memory %> - 1400*1024*1024 - 1*1024*1024 --timeout 60s
    When I run the :run client command with:
      | name       | pod-stress-bu-less                                             |
      | image      | docker.io/ocpqe/stress                                         |
      | requests   | cpu=300m,memory=300Mi                                          |
      | restart    | Never                                                          |
      | command    | true                                                           |
      | oc_opt_end |                                                                |
      | cmd        | stress                                                         |
      | cmd        | --vm                                                           |
      | cmd        | 1                                                              |
      | cmd        | --vm-bytes                                                     |
      | cmd        | <%= cb.node_allocate_memory %> - 1400 * 1024 * 1024 - 1 * 1024 |
      | cmd        | --timeout                                                      |
      | cmd        | 60s                                                            |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    And the pod named "pod-stress-bu-less" status becomes :running
    """
    Given I ensure "pod-stress-bu-less" pod is deleted
    # Consume more than node allocatable memory
    When I run the :run client command with:
      | name       | pod-stress-bu-more                                             |
      | image      | docker.io/ocpqe/stress                                         |
      | requests   | cpu=300m,memory=300Mi                                          |
      | restart    | Never                                                          |
      | command    | true                                                           |
      | oc_opt_end |                                                                |
      | cmd        | stress                                                         |
      | cmd        | --vm                                                           |
      | cmd        | 1                                                              |
      | cmd        | --vm-bytes                                                     |
      | cmd        | <%= cb.node_allocate_memory %> - 1400 * 1024 * 1024 + 1 * 1024 |
      | cmd        | --timeout                                                      |
      | cmd        | 60s                                                            |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pod |
    Then the output should match:
      | pod-stress-bu-more\\s+.*OOMKilled |
    """

