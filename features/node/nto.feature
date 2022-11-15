Feature: Node Tuning Operator related scenarios

  # @author skordas@redhat.com
  # @case_id OCP-27491
  @admin
  @destructive
  @nutanix-ipi @ibmcloud-ipi @alicloud-ipi
  @nutanix-upi @ibmcloud-upi @alicloud-upi
  @4.13
  Scenario: OCP-27491:PSAP Node tuning operator: tuning is working - add profile
    # Cleaning after test if some step failed
    Given admin ensures "nf-conntrack-max" tuned is deleted from the "openshift-cluster-node-tuning-operator" project after scenario
    And I obtain test data file "pods/hello-pod.json"
    And I obtain test data file "node/tuned-nf-conntrack-max.yaml"
    # Creating a new projects with running pod
    And I have a project
    And I run the :create client command with:
      | f | hello-pod.json |
    And the pod named "hello-openshift" becomes ready
    And I run the :label client command with:
      | resource | pod                               |
      | name     | hello-openshift                   |
      | key_val  | tuned.openshift.io/elasticsearch= |
    # Storing node name where pod is deployed
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard
    # Store tuned pod name working on the same node as our new pod.
    And I run the :get admin command with:
      | resource      | pods                                   |
      | o             | custom-columns=:.metadata.name         |
      | n             | openshift-cluster-node-tuning-operator |
      | fieldSelector | spec.nodeName=<%= cb.pod_node %>       |
    And evaluation of `@result[:response].split("\n")[1]` is stored in the :tuned_pod clipboard
    # Creating a new tuned profile
    And I switch to cluster admin pseudo user
    And I use the "openshift-cluster-node-tuning-operator" project
    When I run the :create admin command with:
      | f | tuned-nf-conntrack-max.yaml |
    And the step should succeed
    # Logs verification
    Then I wait up to 30 seconds for the steps to pass:
    """
    And I run the :logs admin command with:
      | resource_name | <%= cb.tuned_pod %>                    |
      | n             | openshift-cluster-node-tuning-operator |
      | tail          | 10                                     |
    And the output should match:
      | tuned.daemon.daemon: static tuning from profile 'nf-conntrack-max' applied |
    """
    # Profile verification
    And the expression should be true> profile(cb.pod_node).tuned_profile == 'nf-conntrack-max'
    # Node verification
    And I run the :debug admin command with:
      | resource     | node/<%= cb.pod_node %>        |
      | oc_opts_end  |                                |
      | exec_command | chroot                         |
      | exec_command | /host                          |
      | exec_command | sysctl                         |
      | exec_command | net.netfilter.nf_conntrack_max |
    And the output should match:
      | net.netfilter.nf_conntrack_max = 1048578 |
    # Removing custom tuned profile
    When admin ensures "nf-conntrack-max" tuned is deleted from the "openshift-cluster-node-tuning-operator" project
    # Logs verification
    Then I wait up to 30 seconds for the steps to pass:
    """
    And I run the :logs admin command with:
      | resource_name | <%= cb.tuned_pod %>                    |
      | n             | openshift-cluster-node-tuning-operator |
      | tail          | 10                                     |
    And the output should match:
      | tuned.daemon.daemon: static tuning from profile 'openshift-node' applied |
    """
    # Profile verification
    And the expression should be true> profile(cb.pod_node).tuned_profile(cached: false) == 'openshift-node'
    # Node verification
    And I run the :debug admin command with:
      | resource     | node/<%= cb.pod_node %>        |
      | oc_opts_end  |                                |
      | exec_command | chroot                         |
      | exec_command | /host                          |
      | exec_command | sysctl                         |
      | exec_command | net.netfilter.nf_conntrack_max |
    And the output should match:
      | net.netfilter.nf_conntrack_max = 1048576 |
