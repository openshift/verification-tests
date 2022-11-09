Feature: Multus-CNI ipv6 related scenarios

  # @author weliang@redhat.com
  # @case_id OCP-28968
  @admin
  @inactive
  Scenario: OCP-28968:SDN IPv6 testing for OCP-21151: Create pods with multus-cni - macvlan bridge mode
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/IPv6/macvlan-bridge-v6.yaml"
    When I run oc create as admin over "macvlan-bridge-v6.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>            |
      | ["spec"]["config"]| '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "host-local", "subnet": "fd00:dead:beef::/64"} }' |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    Given I obtain test data file "networking/multus-cni//Pods/IPv6/1interface-macvlan-bridge-v6.yaml"
    When I run oc create over "1interface-macvlan-bridge-v6.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod-v6 |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode bridge is added to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode bridge"
    When I execute on the pod:
      | bash | -c | ip addr show net1 \| grep -Po 'fd00:dead:beef::[[:xdigit:]]{1,4}' |
    Then the step should succeed
    And evaluation of `@result[:response].chomp` is stored in the :pod1_multus_ipv6 clipboard

    # Create the second pod which consumes the macvlan cr
    Given I obtain test data file "networking/multus-cni//Pods/IPv6/1interface-macvlan-bridge-v6.yaml"
    When I run oc create over "1interface-macvlan-bridge-v6.yaml" replacing paths:
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

  # @author weliang@redhat.com
  # @case_id OCP-38521
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-38521:SDN IPv6 testing for OCP-31999: Whereabouts should exclude IPv6 ranges
  # Bug https://bugzilla.redhat.com/show_bug.cgi?id=1913062
  # Bug https://bugzilla.redhat.com/show_bug.cgi?id=1917984
  # Make sure that the multus is enabled
    Given the master version >= "4.6"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-excludeIP.yaml"
    When I run oc create as admin over "whereabouts-excludeIP.yaml" replacing paths:
      | ["metadata"]["name"]      | whereabouts-excludeipv6                                                                                                                                                                                                  |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                      |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "name": "whereabouts", "type": "macvlan", "mode": "bridge", "ipam": { "type": "whereabouts", "range": "fd00:dead:beef:1::1-fd00:dead:beef:1::4/64", "exclude": ["fd00:dead:beef:1::2/128"] } }'|
    Then the step should succeed

    # Create the three pods which consumes the custom resource
    Given I obtain test data file "networking/multus-cni/Pods/IPv6/ipv6-pod.yaml"
    When I run oc create over "ipv6-pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                                           | "<%= cb.target_node %>" |
      | ["metadata"]["name"]                                                           | test-pod                |
      | ["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeipv6 |
    Then the step should succeed
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should contain:
      | fd00:dead:beef:1::1 |
      | fd00:dead:beef:1::3 |
      | fd00:dead:beef:1::4 |
    And the output should not contain:
      | fd00:dead:beef:1::2 |
    """

    # Create new net-attach-def via cluster admin to exclude address list
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-excludeIP.yaml"
    When I run oc create as admin over "whereabouts-excludeIP.yaml" replacing paths:
      | ["metadata"]["name"]      | whereabouts-excludeipv6-list                                                                                                                                                                                                                                                                                  |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                                           |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "name": "whereabouts", "type": "macvlan", "mode": "bridge", "ipam": { "type": "whereabouts", "range": "fd00:dead:beef:1::10-fd00:dead:beef:1::16/64", "exclude": ["fd00:dead:beef:1::10/128","fd00:dead:beef:1::11/128","fd00:dead:beef:1::12/128", "fd00:dead:beef:1::13/128"] } }'|
    Then the step should succeed

    # Create the three pods which consumes the custom resource
    Given I obtain test data file "networking/multus-cni/Pods/IPv6/ipv6-pod.yaml"
    When I run oc create over "ipv6-pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                                           | "<%= cb.target_node %>"      |
      | ["metadata"]["name"]                                                           | test-pod-list                |
      | ["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeipv6-list |
    Then the step should succeed
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should contain:
      | fd00:dead:beef:1::14 |
      | fd00:dead:beef:1::15 |
      | fd00:dead:beef:1::16 |
    And the output should not contain:
      | fd00:dead:beef:1::10 |
      | fd00:dead:beef:1::11 |
      | fd00:dead:beef:1::12 |
      | fd00:dead:beef:1::13 |
    """

  # @author weliang@redhat.com
  # @case_id OCP-44941
  @admin
  @4.9
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  Scenario: OCP-44941:SDN Whereabouts IPv6 should be calculated if first hextet of IPv6 has leading zeros	
  # Bug https://bugzilla.redhat.com/show_bug.cgi?id=1919048
  # Make sure that the multus is enabled
    Given the master version >= "4.6"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-excludeIP.yaml"
    When I run oc create as admin over "whereabouts-excludeIP.yaml" replacing paths:
      | ["metadata"]["name"]      | whereabouts-excludeipv6                                                                                                                                                                                            |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "name": "whereabouts", "type": "macvlan", "mode": "bridge", "ipam": { "type": "whereabouts", "range": "fd:dead:beef:1::1-fd:dead:beef:1::4/64", "exclude": ["fd:dead:beef:1::2/128"] } }'|
    Then the step should succeed

    # Create the three pods which consumes the custom resource
    Given I obtain test data file "networking/multus-cni/Pods/IPv6/ipv6-pod.yaml"
    When I run oc create over "ipv6-pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                                           | "<%= cb.target_node %>" |
      | ["metadata"]["name"]                                                           | test-pod                |
      | ["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeipv6 |
    Then the step should succeed
    Given 3 pods becomes ready with labels:
      | name=test-pod |
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should contain:
      | fd:dead:beef:1::1 |
      | fd:dead:beef:1::3 |
      | fd:dead:beef:1::4 |
    And the output should not contain:
      | fd:dead:beef:1::2 |
    """

    # Create new net-attach-def via cluster admin to exclude address list
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-excludeIP.yaml"
    When I run oc create as admin over "whereabouts-excludeIP.yaml" replacing paths:
      | ["metadata"]["name"]      | whereabouts-excludeipv6-list                                                                                                                                                                                                                                                                      |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                               |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "name": "whereabouts", "type": "macvlan", "mode": "bridge", "ipam": { "type": "whereabouts", "range": "fd:dead:beef:1::10-fd:dead:beef:1::16/64", "exclude": ["fd:dead:beef:1::10/128","fd:dead:beef:1::11/128","fd:dead:beef:1::12/128", "fd:dead:beef:1::13/128"] } }'|
    Then the step should succeed

    # Create the three pods which consumes the custom resource
    Given I obtain test data file "networking/multus-cni/Pods/IPv6/ipv6-pod.yaml"
    When I run oc create over "ipv6-pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                                           | "<%= cb.target_node %>"      |
      | ["metadata"]["name"]                                                           | test-pod-list                |
      | ["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeipv6-list |
    Then the step should succeed
    Given 3 pods becomes ready with labels:
      | name=test-pod |
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
    Then the output should contain:
      | fd:dead:beef:1::14 |
      | fd:dead:beef:1::15 |
      | fd:dead:beef:1::16 |
    And the output should not contain:
      | fd:dead:beef:1::10 |
      | fd:dead:beef:1::11 |
      | fd:dead:beef:1::12 |
      | fd:dead:beef:1::13 |
    """
