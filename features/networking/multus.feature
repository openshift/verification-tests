Feature: Multus-CNI related scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-21151
  @admin
  Scenario: Create pods with multus-cni - macvlan bridge mode
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster

    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml |
      | n | <%= project.name %> |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-bridge.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode bridge is added to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode bridge"
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip -f inet addr show net1 \| grep -Po 'inet \K[\d.]+' |
    Then the output should match "10.1.1.\d{1,3}"
    And the expression should be true> IPAddr.new(@result[:response].chomp)
    And evaluation of `@result[:response].chomp` is stored in the :pod1_multus_ip clipboard
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip -f inet addr show eth0 \| grep -Po 'inet \K[\d.]+' |
    Then the step should succeed
    And evaluation of `@result[:response].chomp` is stored in the :pod1_sdn_ip clipboard

    # Create the second pod which consumes the macvlan cr
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-bridge.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.pod_node %>" |
    Then the step should succeed
    And 2 pods become ready with labels:
      | name=macvlan-bridge-pod |
    And evaluation of `pod(-1).name` is stored in the :pod2 clipboard

    # Try to access both the cluster ip and macvlan ip on pod1 from pod2
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_sdn_ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_multus_ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
