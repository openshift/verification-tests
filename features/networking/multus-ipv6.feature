Feature: Multus-CNI ipv6 related scenarios  
  
  # @author weliang@redhat.com
  # @case_id OCP-28968
  @admin
  Scenario: IPv6 testing for OCP-21151: Create pods with multus-cni - macvlan bridge mode
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "<%= BushSlicer::HOME %>/testdata/networking/multus-cni/NetworkAttachmentDefinitions/IPv6/macvlan-bridge-v6.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>            |    
      | ["spec"]["config"]| '{ "cniVersion": "0.3.0", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "host-local", "subnet": "fd00:dead:beef::/64"} }' |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/networking/multus-cni//Pods/IPv6/1interface-macvlan-bridge-v6.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod-v6 |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode bridge is added to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode bridge"
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip addr show net1 \| grep -Po 'fd00:dead:beef::[[:xdigit:]]{1,4}' |
    Then the step should succeed
    And evaluation of `@result[:response].chomp` is stored in the :pod1_multus_ipv6 clipboard
  
    # Create the second pod which consumes the macvlan cr
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/networking/multus-cni//Pods/IPv6/1interface-macvlan-bridge-v6.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And 2 pods become ready with labels:
      | name=macvlan-bridge-pod-v6 |
    And evaluation of `pod(-1).name` is stored in the :pod2 clipboard

    # Try to access macvlan ip on pod1 from pod2
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | -g | -6 | --connect-timeout | 5 | [<%= cb.pod1_multus_ipv6 %>]:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
