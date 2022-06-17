Feature: cluster-capacity related features

  # @author wjiang@redhat.com
  # @case_id OCP-14799
  @admin
  Scenario: OCP-14799 Cluster capacity image support: Cluster capacity can work well with a simple pod
    Given environment has at least 2 schedulable nodes
    Given I have a project
    Given I have a cluster-capacity pod in my project
    Given I store the schedulable nodes in the :nodes clipboard
    Given evaluation of `cb.nodes.map {|n| n.max_pod_count_schedulable(cpu: convert_cpu("150m"), memory: convert_to_bytes("100Mi"))}.reduce(&:+)` is stored in the :expected_number_total clipboard
    When I run the :exec client command with:
      | pod               | cluster-capacity              |
      | oc_opts_end       |                               |
      | exec_command      | cluster-capacity              |
      | exec_command_arg  | --kubeconfig                  |
      | exec_command_arg  | /admin-creds/admin.kubeconfig |
      | exec_command_arg  | --podspec                     |
      | exec_command_arg  | /test-pod/pod.yaml            |
    Then the step should succeed
    Then the expression should be true> @result[:response].to_i == cb.expected_number_total

