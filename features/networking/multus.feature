Feature: Multus-CNI related scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-21151
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21151:SDN Create pods with multus-cni - macvlan bridge mode
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                    |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "host-local", "subnet": "10.1.1.0/24", "rangeStart": "10.1.1.100", "rangeEnd": "10.1.1.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "10.1.1.1" } }' |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode bridge is added to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode bridge"
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net1 |
    Then the output should match "10.1.1.\d{1,3}"
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_multus_ip clipboard
    When I execute on the pod:
      | bash | -c | ip -f inet addr show eth0 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_sdn_ip clipboard

    # Create the second pod which consumes the macvlan cr
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
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


  # @author bmeng@redhat.com
  # @case_id OCP-21489
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21489:SDN Create pods with multus-cni - macvlan private mode
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-private.yaml"
    When I run oc create as admin over "macvlan-private.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                     |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "private", "ipam": { "type": "host-local", "subnet": "10.1.1.0/24", "rangeStart": "10.1.1.100", "rangeEnd": "10.1.1.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "10.1.1.1" } }' |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-private.yaml"
    When I run oc create over "1interface-macvlan-private.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-private-pod |

    # Check that the macvlan with mode private is added to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode private"
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net1 |
    Then the output should match "10.1.1.\d{1,3}"
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_multus_ip clipboard
    When I execute on the pod:
      | bash | -c | ip -f inet addr show eth0 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_sdn_ip clipboard

    # Create the second pod which consumes the macvlan cr
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-private.yaml"
    When I run oc create over "1interface-macvlan-private.yaml" replacing paths:
      | ["metadata"]["name"]              | macvlan-private-secondpod |
      | ["spec"]["nodeName"]              | "<%= cb.target_node %>"   |
      | ["spec"]["containers"][0]["name"] | macvlan-private-secondpod |
    Then the step should succeed
    And the pod named "macvlan-private-secondpod" becomes ready

    # Try to access both the cluster ip and macvlan ip on pod1 from pod2
    When I execute on the "macvlan-private-secondpod" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_sdn_ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    When I execute on the "macvlan-private-secondpod" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_multus_ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello OpenShift"

  # @author bmeng@redhat.com
  # @case_id OCP-21496
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21496:SDN Create pods with multus-cni - macvlan vepa mode
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-vepa.yaml"
    When I run oc create as admin over "macvlan-vepa.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                  |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "vepa", "ipam": { "type": "host-local", "subnet": "10.1.1.0/24", "rangeStart": "10.1.1.100", "rangeEnd": "10.1.1.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "10.1.1.1" } }' |
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-vepa.yaml"
    When I run oc create over "1interface-macvlan-vepa.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-vepa-pod |

    # Check that the macvlan with mode vepa is added to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode vepa"
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net1 |
    Then the output should match "10.1.1.\d{1,3}"
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_multus_ip clipboard
    When I execute on the pod:
      | bash | -c | ip -f inet addr show eth0 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_sdn_ip clipboard

    # Create the second pod which consumes the macvlan cr
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-vepa.yaml"
    When I run oc create over "1interface-macvlan-vepa.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And 2 pods become ready with labels:
      | name=macvlan-vepa-pod |
    And evaluation of `pod(-1).name` is stored in the :pod2 clipboard

    # Try to access both the cluster ip and macvlan ip on pod1 from pod2
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_sdn_ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    # skip the interface accessing test for the macvlan since the vepa mode needs the switch support which may not work on AWS currently
    #When I execute on the "<%= cb.pod2 %>" pod:
    #  | curl | --connect-timeout | 5 | <%= cb.pod1_multus_ip %>:8080 |
    #Then the step should succeed
    #And the output should contain "Hello OpenShift"

  # @author bmeng@redhat.com
  # @case_id OCP-21853
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @upgrade-sanity
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21853:SDN Create pods with multus-cni - host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    And an 4 character random string of type :hex is stored into the :nic_name clipboard

    # Prepare the net link on the node which will be attached to the pod
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link add <%= cb.nic_name %> link <%= cb.default_interface %> type macvlan mode bridge |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run command on the "<%= cb.target_node %>" node's sdn pod:
       | sh | -c | ip link del <%= cb.nic_name %> |
    the step should succeed
    """

    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml"
    When I run oc create as admin over "host-device.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                              |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.1", "type": "host-device", "device": "<%= cb.nic_name %>"}' |
    Then the step should succeed
    # Create the first pod which consumes the host-device custom resource
    Given I obtain test data file "networking/multus-cni/Pods/1interface-host-device.yaml"
    When I run oc create over "1interface-host-device.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=host-device-pod |
    And evaluation of `pod.name` is stored in the :hostdev_pod clipboard

    # Check that the host-device is added to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode bridge"

    # Make sure that the pod's master network works fine
    Given I have a pod-for-ping in the project
    And evaluation of `pod.ip` is stored in the :ping_pod clipboard
    When I execute on the "<%= cb.hostdev_pod %>" pod:
      | curl | --connect-timeout | 5 | -sS | <%= cb.ping_pod%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"

    # Check that the link is removed from node
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link show |
    Then the step should succeed
    And the output should not contain "<%= cb.nic_name %>"

    # Delete the pod and check the link on the node again
    When I run the :delete client command with:
      | object_type | pod                  |
      | l           | name=host-device-pod |
    Then the step should succeed
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link show |
    Then the step should succeed
    And the output should contain "<%= cb.nic_name %>"


  # @author bmeng@redhat.com
  # @case_id OCP-21854
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @baremetal-ipi
  @vsphere-upi @baremetal-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21854:SDN Create pods with muliple cni plugins via multus-cni - macvlan + macvlan
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                    |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "host-local", "subnet": "10.1.1.0/24", "rangeStart": "10.1.1.100", "rangeEnd": "10.1.1.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "10.1.1.1" } }' |
    Then the step should succeed

    # Create the pod which consumes multiple macvlan custom resources
    Given I obtain test data file "networking/multus-cni/Pods/2interface-macvlan-macvlan.yaml"
    When I run oc create over "2interface-macvlan-macvlan.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge, macvlan-bridge |
      | ["spec"]["nodeName"]                                       | "<%= cb.target_node %>"        |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=two-macvlan-pod |

    # Check that there are two additional interfaces attached to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    Then the output should contain "net2"
    And the output should contain 2 times:
      | macvlan mode bridge |
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net1 |
    Then the output should match "10.1.1.\d{1,3}"
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod_multus_ip1 clipboard
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net2 |
    Then the output should match "10.1.1.\d{1,3}"
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod_multus_ip2 clipboard
    And the expression should be true> cb.pod_multus_ip1 != cb.pod_multus_ip2

  # @author bmeng@redhat.com
  # @case_id OCP-21855
  @flaky
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21855:SDN Create pods with muliple cni plugins via multus-cni - macvlan + host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    And an 4 character random string of type :hex is stored into the :nic_name clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                                    |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "host-local", "subnet": "10.1.1.0/24", "rangeStart": "10.1.1.100", "rangeEnd": "10.1.1.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "10.1.1.1" } }' |
    Then the step should succeed
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml"
    When I run oc create as admin over "host-device.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                              |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.1", "type": "host-device", "device": "<%= cb.nic_name %>"}' |
    Then the step should succeed

    # Prepare the net link on the node which will be attached to the pod
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link add <%= cb.nic_name%> link <%= cb.default_interface %> type macvlan mode private |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run command on the "<%= cb.target_node %>" node's sdn pod:
       | sh | -c | ip link del <%= cb.nic_name%> |
    the step should succeed
    """

    # Create the pod which consumes both hostdev and macvlan custom resources
    Given I obtain test data file "networking/multus-cni/Pods/2interface-macvlan-hostdevice.yaml"
    When I run oc create over "2interface-macvlan-hostdevice.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run the :delete client command with:
      | object_type | pod                         |
      | l           | name=macvlan-hostdevice-pod |
    the step should succeed
    all existing pods die with labels:
      | name=macvlan-hostdevice-pod |
    """
    And a pod becomes ready with labels:
      | name=macvlan-hostdevice-pod |

    # Check that there are two additional interfaces attached to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "net2"
    And the output should contain "macvlan mode bridge"
    And the output should contain "macvlan mode private"
    When I execute on the pod:
      | bash | -c | ip -f inet addr show net2 |
    Then the output should match "10.1.1.\d{1,3}"
    And the expression should be true> IPAddr.new(@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0])

  # @author bmeng@redhat.com
  # @case_id OCP-21859
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21859:SDN Create pods with muliple cni plugins via multus-cni - host-device + host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.1"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    And an 4 character random string of type :hex is stored into the :nic_name1 clipboard
    And an 4 character random string of type :hex is stored into the :nic_name2 clipboard

    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml"
    When I run oc create as admin over "host-device.yaml" replacing paths:
      | ["metadata"]["name"]      | host-device                                                                      |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.1", "type": "host-device", "device": "<%= cb.nic_name1%>"}' |
      | ["metadata"]["namespace"] | <%= project.name %>                                                              |
    Then the step should succeed
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml"
    When I run oc create as admin over "host-device.yaml" replacing paths:
      | ["metadata"]["name"]      | host-device-2                                                                    |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.1", "type": "host-device", "device": "<%= cb.nic_name2%>"}' |
      | ["metadata"]["namespace"] | <%= project.name %>                                                              |
    Then the step should succeed

    # Prepare the net link on the node which will be attached to the pod
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link add <%= cb.nic_name1%> link <%= cb.default_interface %> type macvlan mode bridge |
    Then the step should succeed
    When I run command on the "<%= cb.target_node %>" node's sdn pod:
      | sh | -c | ip link add <%= cb.nic_name2%> link <%= cb.default_interface %> type macvlan mode bridge |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run command on the "<%= cb.target_node %>" node's sdn pod:
       | sh | -c | ip link del <%= cb.nic_name1%> |
    the step should succeed
    I run command on the "<%= cb.target_node %>" node's sdn pod:
       | sh | -c | ip link del <%= cb.nic_name2%> |
    the step should succeed
    """

    # Create the pod which consumes two hostdev custom resources
    Given I obtain test data file "networking/multus-cni/Pods/2interface-hostdevice-hostdevice.yaml"
    When I run oc create over "2interface-hostdevice-hostdevice.yaml" replacing paths:
      | ["spec"]["nodeName"]                                       | "<%= cb.target_node %>"    |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | host-device, host-device-2 |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run the :delete client command with:
      | object_type | pod                      |
      | l           | name=two-host-device-pod |
    the step should succeed
    all existing pods die with labels:
      | name=two-host-device-pod |
    """
    And a pod becomes ready with labels:
      | name=two-host-device-pod |

    # Check that there are two additional interfaces attached to the pod
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "net2"
    And the output should contain 2 times:
      | macvlan mode bridge |

  # @author anusaxen@redhat.com
  # @case_id OCP-24488
  @admin
  @serial
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24488:SDN Create pod with Multus bridge CNI plugin without vlan
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-novlan.yaml"
    When I run the :create admin command with:
      | f | bridge-host-local-novlan.yaml |
      | n | <%= project.name %>           |
    Then the step should succeed
    #Creating no-vlan pod absorbing above net-attach-def
    Given I store the ready and schedulable workers in the :nodes clipboard
    And CNI vlan info is obtained on the "<%= cb.nodes[0].name %>" node
    And evaluation of `@result[:parsed]` is stored in the :vlans_before clipboard
    # force pod onto the node we already got CNI vlan information for
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod-novlan              |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridge3                 |
      | ["spec"]["containers"][0]["name"]                          | pod-novlan              |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "pod-novlan" becomes ready
    And evaluation of `pod` is stored in the :pod clipboard

    #Clean-up required to erase bridge interfcaes created on node after this step
    Given I register clean-up steps:
    """
    the bridge interface named "bridge3" is deleted from the "<%= cb.pod.node_name %>" node
    """
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"
    #Entering into corresponding no eot make sure No VLAN ID information shown for secondary interface
    Given CNI vlan info is obtained on the "<%= cb.pod.node_name %>" node
    Then the step should succeed
    And evaluation of `@result[:parsed]` is stored in the :vlans_after clipboard
    # check "ntagged" substring due to iproute2 changes,
    # iproute2 before v4.19.0 should output "untagged"
    # https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/commit/bridge/vlan.c?h=v5.3.0&id=0f36267485e30099a4f735c3aadfa58b5efa1918
    # after v4.19.0 it should output "Egress Untagged"
    Given the number of bridge PVID 1 VLANs matching "ntagged" added between the :vlans_before and :vlans_after clipboards is 2


  # @author anusaxen@redhat.com
  # @case_id OCP-24489
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24489:SDN Create pod with Multus bridge CNI plugin and vlan tag
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-vlan-200.yaml"
    When I run the :create admin command with:
      | f | bridge-host-local-vlan-200.yaml |
      | n | <%= project.name %>             |
    Then the step should succeed
    #Creating vlan pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod1-vlan200  |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan200 |
      | ["spec"]["containers"][0]["name"]                          | pod1-vlan200  |
    Then the step should succeed
    And the pod named "pod1-vlan200" becomes ready
    And evaluation of `pod` is stored in the :pod clipboard

    #Clean-up required to erase bridge interfcaes created on node after this step
    Given I register clean-up steps:
    """
    the bridge interface named "mybridge" is deleted from the "<%= cb.pod.node_name %>" node
    the bridge interface named "mybridge.200" is deleted from the "<%= cb.pod.node_name %>" node
    """
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1 |
    #Entering into corresponding node to make sure VLAN ID information shown for interfaces
    Given CNI vlan info is obtained on the "<%= cb.pod.node_name %>" node
    Then the step should succeed
    And the output should contain:
      | 200 |

  # @author anusaxen@redhat.com
  # @case_id OCP-24467
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24467:SDN CNO manager mavlan configured manually with static
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    #Patching simplemacvlan config in network operator config CRD
    Given I have a project
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks":[{"name":"test-macvlan-case3","namespace":"<%= project.name %>","simpleMacvlanConfig":{"ipamConfig":{"staticIPAMConfig":{"addresses": [{"address":"10.128.2.100/23","gateway":"10.128.2.1"}]},"type":"static"},"master":"<%= cb.default_interface %>","mode":"bridge"},"type":"SimpleMacvlan"}]}} |
    #Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |
    """

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | net-attach-def      |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | test-macvlan-case3 |
    """
    #Creating pod under openshift-multus project to absorb above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | test-macvlan-case3      |
      | ["metadata"]["namespace"]                                  | <%= project.name %>     |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod |
    And evaluation of `pod` is stored in the :pod clipboard
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"

  # @author anusaxen@redhat.com
  # @case_id OCP-21946
  @admin
  Scenario: OCP-21946:SDN The multus admission controller should be able to detect the syntax issue in the net-attach-def
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin and simulating syntax errors
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["name"] | macvlan-bridge-21756 |
      | ["spec"]["config"]   | 'asdf'               |
    Then the step should fail
    And the output should contain:
      | admission webhook "multus-validating-config.k8s.io" denied the request |
    And admin ensures "macvlan-bridge-21756" network_attachment_definition is deleted from the "<%= project.name %>" project after scenario
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["name"] | macvlan-bridge@$ |
    Then the step should fail
    And the output should contain:
      | subdomain must consist of lower case alphanumeric characters |
    And admin ensures "macvlan-bridge@$" network_attachment_definition is deleted from the "<%= project.name %>" project after scenario

  # @author anusaxen@redhat.com
  # @case_id OCP-21949
  @admin
  @inactive
  Scenario: OCP-21949:SDN The multus admission controller should be able to detect the issue in the pod template
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml"" replacing paths:
      | ["metadata"]["name"] | macvlan-bridge-21456 |
    Then the step should succeed
    And admin ensures "macvlan-bridge-21456" network_attachment_definition is deleted from the "default" project after scenario
    # Create a pod consuming net-attach-def simulating wrong syntax in name
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create as admin over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["generateName"] | macvlan-bridge-pod-$@ |
    Then the step should fail
    And the output should contain:
      | subdomain must consist of lower case alphanumeric characters |

  # @author anusaxen@redhat.com
  # @case_id OCP-21793
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-21793:SDN User cannot consume the net-attach-def created in other project which is namespace isolated
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    Given I have a project
    And evaluation of `project.name` is stored in the :project1 clipboard
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["name"]      | macvlan-bridge-21793 |
      | ["metadata"]["namespace"] | <%= project.name %>  |
    Then the step should succeed

    # Creating pod in the another namespace which consumes the net-attach-def created in project1 namespace
    Given I create a new project
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | <%= cb.project1 %>/macvlan-bridge-21793 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/pod\/(.*) created/)[1]` is stored in the :pod_name clipboard
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | events                 |
      | name     | <%= cb.pod_name %>     |
      | n        | <%= cb.project_name %> |
    Then the step should succeed
    And the output should contain:
      | namespace isolation |
      | violat              |
    """

  # @author anusaxen@redhat.com
  # @case_id OCP-24490
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24490:SDN Pods can communicate each other with same vlan tag
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    Given I have a project
    And the appropriate pod security labels are applied to the namespace
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-vlan.yaml"
    When I run the :create admin command with:
      | f | bridge-host-local-vlan.yaml |
      | n | <%= project.name %>         |
    Then the step should succeed

    #Creating first pod in vlan 100
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod_net_raw.yaml"
    When I run oc create as admin over "generic_multus_pod_net_raw.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod1-vlan100            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan100           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
      | ["metadata"]["namespace"]                                  | <%= project.name %>     |
    Then the step should succeed
    And the pod named "pod1-vlan100" becomes ready
    #Clean-up required to erase bridge interfaces created due to above pod on same node
    Given I register clean-up steps:
    """
    the bridge interface named "mybridge" is deleted from the "<%= cb.nodes[0].name %>" node
    the bridge interface named "mybridge.100" is deleted from the "<%= cb.nodes[0].name %>" node
    """
    And evaluation of `pod.name` is stored in the :pod1 clipboard
    And admin executes on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_net1_ip clipboard

    #Creating 2nd pod on same node as first in vlan 100
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod_net_raw.yaml"
    When I run oc create as admin over "generic_multus_pod_net_raw.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod2-vlan100            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan100           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
      | ["metadata"]["namespace"]                                  | <%= project.name %>     |
    Then the step should succeed
    And the pod named "pod2-vlan100" becomes ready
    And evaluation of `pod.name` is stored in the :pod2 clipboard
    And admin executes on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod2_net1_ip clipboard

    #Creating 3rd pod on different node in vlan 100
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod_net_raw.yaml"
    When I run oc create as admin over "generic_multus_pod_net_raw.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod3-vlan100            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan100           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[1].name %> |
      | ["metadata"]["namespace"]                                  | <%= project.name %>     |
    Then the step should succeed
    And the pod named "pod3-vlan100" becomes ready
    #Clean-up required to erase bridge interfcaes created on node
    Given I register clean-up steps:
    """
    the bridge interface named "mybridge" is deleted from the "<%= cb.nodes[1].name %>" node
    the bridge interface named "mybridge.100" is deleted from the "<%= cb.nodes[1].name %>" node
    """
    And evaluation of `pod.name` is stored in the :pod3 clipboard
    And admin executes on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod3_net1_ip clipboard

    #making sure the pods on same node can ping while pods on diff nodes can't
    When admin executes on the "<%= cb.pod1 %>" pod:
      | arping | -I | net1 | -c1 | -w2 | <%= cb.pod2_net1_ip %> |
    Then the step should succeed

    When admin executes on the "<%= cb.pod3 %>" pod:
      | arping | -I | net1 | -c1 | -w2 | <%= cb.pod1_net1_ip %> |
    Then the step should fail

    When admin executes on the "<%= cb.pod3 %>" pod:
      | arping | -I | net1 | -c1 | -w2 | <%= cb.pod2_net1_ip %> |
    Then the step should fail

  # @author anusaxen@redhat.com
  # @case_id OCP-24491
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24491:SDN Pods cannot communicate each other with different vlan tag
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    # Create the net-attach-def with vlan 100 via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-vlan.yaml"
    When I run the :create admin command with:
      | f | bridge-host-local-vlan.yaml |
      | n | <%= project.name %>         |
    Then the step should succeed

    # Create the net-attach-def with vlan 200 via cluster admin
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-vlan-200.yaml"
    When I run the :create admin command with:
      | f | bridge-host-local-vlan-200.yaml |
      | n | <%= project.name %>             |
    Then the step should succeed

    #Creating first pod in vlan 100
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod1-vlan100            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan100           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "pod1-vlan100" becomes ready
    #Clean-up required to erase bridge interfcaes created on same node above due to vlan pods
    Given I register clean-up steps:
    """
    the bridge interface named "mybridge" is deleted from the "<%= cb.nodes[0].name %>" node
    the bridge interface named "mybridge.100" is deleted from the "<%= cb.nodes[0].name %>" node
    """
    And evaluation of `pod.name` is stored in the :pod1 clipboard
    And I execute on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_net1_ip clipboard

    #Creating 2nd pod on same node as first in vlan 100
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod2-vlan100            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan100           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "pod2-vlan100" becomes ready
    And evaluation of `pod.name` is stored in the :pod2 clipboard
    And I execute on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod2_net1_ip clipboard

    #Creating 3rd pod on same node but in vlan 200
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod3-vlan200            |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridgevlan200           |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "pod3-vlan200" becomes ready
    #Clean-up required to erase bridge interfcaes created on same node above due to vlan pods
    Given I register clean-up steps:
    """
    the bridge interface named "mybridge.200" is deleted from the "<%= cb.nodes[0].name %>" node
    """
    And evaluation of `pod.name` is stored in the :pod3 clipboard
    And I execute on the pod:
      | ifconfig | net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod3_net1_ip clipboard

    #making sure the pods in same vlan can communicate but in different vlans cannot
    When I execute on the "<%= cb.pod1 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod2_net1_ip %> |
    Then the step should succeed

    When I execute on the "<%= cb.pod2 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod1_net1_ip %> |
    Then the step should succeed

    When I execute on the "<%= cb.pod1 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod3_net1_ip %> |
    Then the step should fail

    When I execute on the "<%= cb.pod3 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod1_net1_ip %> |
    Then the step should fail

    When I execute on the "<%= cb.pod3 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod2_net1_ip %> |
    Then the step should fail

    When I execute on the "<%= cb.pod2 %>" pod:
      | ping | -c1 | -W2 | <%= cb.pod3_net1_ip %> |
    Then the step should fail

  # @author anusaxen@redhat.com
  # @case_id OCP-24607
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24607:SDN macvlan plugin without master parameter
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def without master pmtr via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-conf-without-master.yaml"
    When I run the :create admin command with:
      | f | macvlan-conf-without-master.yaml |
      | n | <%= project.name %>              |
    Then the step should succeed

    #Creating a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-conf |
    Then the step should succeed
    And the pod named "test-pod" becomes ready
    And evaluation of `pod` is stored in the :pod clipboard
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain "net1"

  # @author weliang@redhat.com
  # @case_id OCP-25676
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-25676:SDN Supported runtimeConfig/capability for MAC/IP
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster

    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/runtimeconfig-def-ipandmac.yaml"
    When I run the :create admin command with:
      | f | runtimeconfig-def-ipandmac.yaml |
      | n | <%= project.name %>             |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/runtimeconfig-pod-ipandmac.yaml"
    When I run the :create client command with:
      | f | runtimeconfig-pod-ipandmac.yaml |
      | n | <%= project.name %>             |
    Then the step should succeed
    And the pod named "runtimeconfig-pod" becomes ready

    # Check created pod has correct MAC and IP for interface net1
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    When I execute on the pod:
      | ip | a |
    Then the output should contain:
      | 192.168.22.2      |
      | ca:fe:c0:ff:ee:00 |

  # @author anusaxen@redhat.com
  # @case_id OCP-24465
  @inactive
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24465:SDN Multus CNI type bridge with DHCP
    # Make sure that the multus is Running
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And I store all worker nodes to the :nodes clipboard
    #Patching config in network operator config CRD
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": [{"name":"bridge-ipam-dhcp","namespace":"openshift-multus","rawCNIConfig":"{\"name\":\"bridge-ipam-dhcp\",\"cniVersion\":\"0.3.1\",\"type\":\"bridge\",\"master\":\"<%= cb.default_interface %>\",\"ipam\":{\"type\": \"dhcp\"}}","type":"Raw"}]}} |
    #Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
    | {"spec":{"additionalNetworks": null}} |
    """
    And admin ensures "bridge-ipam-dhcp" network_attachment_definition is deleted from the "openshift-multus" project after scenario
    #Adding brige interface on target node
    Given the bridge interface named "testbr1" with address "88.8.8.191/24" is added to the "<%= cb.nodes[0].name %>" node
    #Cleanup for deleting testbr1 interface
    Given I register clean-up steps:
    """
    the bridge interface named "testbr1" is deleted from the "<%= cb.nodes[0].name %>" node
    """
    #Configuring DHCP service on target node
    And a DHCP service is configured for interface "testbr1" on "<%= cb.nodes[0].name %>" node with address range and lease time as "88.8.8.100,88.8.8.110,24h"
    #Cleanup for deconfiguring DHCP service on target node
    Given I register clean-up steps:
    """
    a DHCP service is deconfigured on the "<%= cb.nodes[0].name %>" node
    """
    #Creating ipam type net-attach-def
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/ipam-dhcp.yaml"
    When I run oc create as admin over "ipam-dhcp.yaml" replacing paths:
      | ["metadata"]["name"]      | bridge-dhcp                                                                                                                                               |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                       |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "bridge", "bridge": "testbr1", "hairpinMode": true, "master": "<%= cb.default_interface %>", "ipam": {"type": "dhcp"}}' |
    Then the step should succeed

    #Creating dhcp pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["namespace"]                                  | <%= project.name %>     |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridge-dhcp             |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "test-pod" becomes ready
    When I execute on the pod:
      | ip | a |
    Then the output should contain "88.8.8"

  # @author anusaxen@redhat.com
  # @case_id OCP-24466
  @admin
  @destructive
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @inactive
  Scenario: OCP-24466:SDN CNO manager macvlan configured manually with DHCP
    Given the multus is enabled on the cluster
    And I store the masters in the :master clipboard
    And I store all worker nodes to the :worker clipboard
    #Obtaining master's tunnel interface name, address and worker's interface name,address
    Given the vxlan tunnel name of node "<%= cb.master[0].name %>" is stored in the :mastr_inf_name clipboard
    And the vxlan tunnel address of node "<%= cb.master[0].name %>" is stored in the :mastr_inf_address clipboard
    Given the vxlan tunnel name of node "<%= cb.worker[0].name %>" is stored in the :workr_inf_name clipboard
    And the vxlan tunnel address of node "<%= cb.worker[0].name %>" is stored in the :workr_inf_address clipboard
    #Configuing tunnel interface on a worker node
    Given I use the "<%= cb.worker[0].name %>" node
    And I run commands on the host:
      | ip link add mvlanp0 type vxlan id 100 remote <%= cb.mastr_inf_address %> dev <%= cb.workr_inf_name %> dstport 14789 |
      | ip link set up mvlanp0                                                                                              |
      | ip a add 192.18.0.10/15 dev mvlanp0                                                                                 |
    Then the step should succeed
    #Cleanup for deleting worker interface
    Given I register clean-up steps:
    """
    the bridge interface named "mvlanp0" is deleted from the "<%= cb.worker[0].name %>" node
    """
    #Configuing tunnel interface on master node
    Given I use the "<%= cb.master[0].name %>" node
    And I run commands on the host:
      | ip link add mvlanp0 type vxlan id 100 remote <%= cb.workr_inf_address %> dev <%= cb.mastr_inf_name %> dstport 14789 |
      | ip link set up mvlanp0                                                                                              |
      | ip a add 192.18.0.20/15 dev mvlanp0                                                                                 |
    Then the step should succeed
    #Cleanup for deleting master interface
    Given I register clean-up steps:
    """
    the bridge interface named "mvlanp0" is deleted from the "<%= cb.master[0].name %>" node
    """
    #Confirm the link connectivity between master and worker
    When I run commands on the host:
      | ping -c1 -W2 192.18.0.20 |
    Then the step should succeed
    Given I use the "<%= cb.worker[0].name %>" node
    And I run commands on the host:
      | ping -c1 -W2 192.18.0.10 |
    Then the step should succeed

    #Configuring DHCP service on master node
    Given a DHCP service is configured for interface "mvlanp0" on "<%= cb.master[0].name %>" node with address range and lease time as "192.18.0.100,192.18.0.120,24h"
    #Cleanup for deconfiguring DHCP service on target node
    Given I register clean-up steps:
    """
    a DHCP service is deconfigured on the "<%= cb.master[0].name %>" node
    """
    Given I have a project
    #Patching simplemacvlan config in network operator config CRD
    And as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec": {"additionalNetworks": [{"name": "testmacvlan","namespace": "<%= project.name %>","simpleMacvlanConfig": {"ipamConfig": {"type": "dhcp"},"master": "mvlanp0"},"type": "SimpleMacvlan"}]}} |
    #Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |
    """
    #Creating pod under test project to absorb above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["namespace"]                                  | <%= project.name %>      |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | testmacvlan              |
      | ["spec"]["nodeName"]                                       | <%= cb.worker[0].name %> |
    Then the step should succeed
    And the pod named "test-pod" becomes ready
    When I execute on the pod:
      | ip | a |
    Then the output should contain "192.18.0"

  # @author weliang@redhat.com
  # @case_id OCP-25909
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-25909:SDN Assign static IP address using pod annotation
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster

    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/runtimeconfig-def-ip.yaml"
    When I run the :create admin command with:
      | f | runtimeconfig-def-ip.yaml |
      | n | <%= project.name %>       |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/runtimeconfig-pod-ip.yaml"
    When I run the :create client command with:
      | f | runtimeconfig-pod-ip.yaml |
      | n | <%= project.name %>       |
    Then the step should succeed
    And the pod named "runtimeconfig-pod-ip" becomes ready

    # Check created pod has correct IP for interface net1
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    When I execute on the pod:
      | ip | a |
    Then the output should contain:
      | 192.168.22.2 |

  # @author weliang@redhat.com
  # @case_id OCP-25910
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-25910:SDN Assign static MAC address using pod annotation
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/runtimeconfig-def-mac.yaml"
    When I run the :create admin command with:
      | f | runtimeconfig-def-mac.yaml |
      | n | <%= project.name %>        |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/runtimeconfig-pod-mac.yaml"
    When I run the :create client command with:
      | f | runtimeconfig-pod-mac.yaml |
      | n | <%= project.name %>        |
    Then the step should succeed
    And the pod named "runtimeconfig-pod-mac" becomes ready
    # Check created pod has correct MAC interface net1
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    When I execute on the pod:
      | ip | a |
    Then the output should contain:
      | c2:b0:57:49:47:f1 |

  # @author weliang@redhat.com
  # @case_id OCP-25915
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-25915:SDN Multus default route overwrite
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/ipam-static.yaml"
    When I run oc create as admin over "ipam-static.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                      |
      | ["metadata"]["name"]      | bridge-static                                                                                                                            |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "bridge", "ipam": {"type":"static","addresses": [{"address": "22.2.2.22/24","gateway": "22.2.2.1"}]}}' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/multus-default-route-pod.yaml"
    When I run the :create client command with:
      | f | multus-default-route-pod.yaml |
      | n | <%= project.name %>           |
    Then the step should succeed
    And the pod named "multus-default-route-pod" becomes ready

    # Check created pod has correct default route
    When I execute on the pod:
      | ip | route |
    Then the output should contain:
      | default via 22.2.2.254 dev net1 |

  # @author weliang@redhat.com
  # @case_id OCP-25917
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-25917:SDN Multus Telemetry Adds capability to track usage of network attachment definitions
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    Given I switch to cluster admin pseudo user
    Given admin uses the "openshift-multus" project
    Then a pod is present with labels:
      | app=multus-admission-controller |
    And evaluation of `@pods[0].name` is stored in the :pod_name clipboard

    When admin executes on the "<%=cb.pod_name%>" pod:
      | /usr/bin/curl | localhost:9091/metrics |
    Then the output should contain:
      | network_attachment_definition_instances{networks="any"} 0 |

    # Create the net-attach-def via cluster admin
    Given I switch to the first user
    Given I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard

    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/runtimeconfig-def-mac.yaml"
    When I run the :create admin command with:
      | f | runtimeconfig-def-mac.yaml |
      | n | <%= project.name %>        |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/runtimeconfig-pod-mac.yaml"
    When I run the :create client command with:
      | f | runtimeconfig-pod-mac.yaml |
      | n | <%= project.name %>        |
    Then the step should succeed
    And the pod named "runtimeconfig-pod-mac" becomes ready

    # Track usage of network attachment definitions
    Given admin uses the "openshift-multus" project
    When admin executes on the "<%=cb.pod_name%>" pod:
      | /usr/bin/curl | localhost:9091/metrics |
    Then the output should contain:
      | network_attachment_definition_instances{networks="any"} 1     |
      | network_attachment_definition_instances{networks="macvlan"} 1 |

    # Delete created pod and svc
    Given I switch to the first user
    Given I ensure "runtimeconfig-pod-mac" pod is deleted from the "<%= cb.usr_project%>" project

    # Track usage of network attachment definitions
    Given admin uses the "openshift-multus" project
    When admin executes on the "<%=cb.pod_name%>" pod:
      | /usr/bin/curl | localhost:9091/metrics |
    Then the output should contain:
      | network_attachment_definition_instances{networks="any"} 0     |
      | network_attachment_definition_instances{networks="macvlan"} 0 |

  # @author anusaxen@redhat.com
  # @case_id OCP-22504
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-22504:SDN The multus admission controller should be able to detect that the pod is using net-attach-def in other namespaces when the isolation is enabled
    Given I create 2 new projects
    # Create the net-attach-def via cluster admin
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml"
    When I run oc create as admin over "macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["name"]      | macvlan-bridge-25657    |
      | ["metadata"]["namespace"] | <%= project(-1).name %> |
    Then the step should succeed
    Given I use the "<%= project(-2).name %>" project
    # Create a pod in new project consuming net-attach-def from 1st project
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-25657 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/pod\/(.*) created/)[1]` is stored in the :pod_name clipboard
    #making sure the created pod complains about net-attach-def and hence stuck in ContainerCreating state
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pods               |
      | name     | <%= cb.pod_name %> |
    Then the step should succeed
    And the output should contain:
      | cannot find a network-attachment-definition |
      | ContainerCreating                           |
    """

  # @author anusaxen@redhat.com
  # @case_id OCP-24492
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  Scenario: OCP-24492:SDN Create pod with Multus ipvlan CNI plugin
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    And the default interface on nodes is stored in the :default_interface clipboard
    #Storing default interface mac address for comparison later with pods macs
    Given I run commands on the host:
      | ip addr show <%= cb.default_interface %> |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\h+:\h+:\h+:\h+:\h+:\h+/)[0]` is stored in the :default_interface_mac clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/ipvlan-host-local.yaml"
    When I run oc create as admin over "ipvlan-host-local.yaml" replacing paths:
      | ["metadata"]["name"]      | myipvlan76                                                                                                                                                              |
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                     |
      | ["spec"] ["config"]       | '{ "cniVersion": "0.3.1", "name": "myipvlan76", "type": "ipvlan", "master": "<%= cb.default_interface %>", "ipam": { "type": "host-local", "subnet": "22.2.2.0/24" } }' |
    Then the step should succeed

    #Creating various pods and making sure their mac matches to default inf and they get unique IPs assigned
    #Creating pod1 absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod1             |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | myipvlan76       |
      | ["spec"]["nodeName"]                                       | <%= node.name %> |
    Then the step should succeed
    And the pod named "pod1" becomes ready
    When I execute on the pod:
      | bash | -c | ip a show net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod1_net1_ip clipboard
    And evaluation of `@result[:response].match(/\h+:\h+:\h+:\h+:\h+:\h+/)[0]` is stored in the :pod1_net1_mac clipboard
    And the expression should be true> cb.pod1_net1_mac == cb.default_interface_mac

    #Creating pod2 absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | pod2             |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | myipvlan76       |
      | ["spec"]["nodeName"]                                       | <%= node.name %> |
    Then the step should succeed
    And the pod named "pod2" becomes ready
    When I execute on the pod:
      | bash | -c | ip a show net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod2_net1_ip clipboard
    And evaluation of `@result[:response].match(/\h+:\h+:\h+:\h+:\h+:\h+/)[0]` is stored in the :pod2_net1_mac clipboard
    And the expression should be true> cb.pod2_net1_mac == cb.default_interface_mac
    And the expression should be true> !(cb.pod2_net1_ip == cb.pod1_net1_ip)

  # @author weliang@redhat.com
  # @case_id OCP-28633
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-28633:SDN Dynamic IP address assignment with Whereabouts
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-macvlan.yaml"
    When I run oc create as admin over "whereabouts-macvlan.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                      |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "whereabouts", "range": "192.168.22.100/30"} }' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-whereabouts      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge-whereabouts      |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod1" becomes ready

    # Check created pod has correct macvlan mode on interface net1
    When I execute on the "macvlan-bridge-whereabouts-pod1" pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    # Check created pod has correct ip address on interface net1
    When I execute on the "macvlan-bridge-whereabouts-pod1" pod:
      | ip | a |
    Then the output should contain:
      | 192.168.22.101 |

    # Create second pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod2 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-whereabouts      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge-whereabouts      |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod2" becomes ready

    # Check created pod has correct macvlan mode on interface net1
    When I execute on the "macvlan-bridge-whereabouts-pod2" pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    # Check created pod has correct ip address on interface net1
    When I execute on the "macvlan-bridge-whereabouts-pod2" pod:
      | ip | a |
    Then the output should contain:
      | 192.168.22.102 |

  # @author weliang@redhat.com
  # @case_id OCP-28518
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-28518:SDN Multus custom route change with route override
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/route-override.yaml"
    When I run oc create as admin over "route-override.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                                                                                                                 |
      | ["metadata"]["name"]      | route-override                                                                                                                                                                                                                                                      |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "name" : "mymacvlan", "plugins": [ { "type": "macvlan", "mode": "bridge", "ipam": { "type": "static", "addresses": [{"address": "192.168.20.2/24"}] } }, { "type" : "route-override", "addroutes": [ { "dst": "192.168.10.0/24" }] } ] }' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | route-override |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | route-override |
      | ["spec"]["containers"][0]["name"]                          | route-override |
    Then the step should succeed
    And the pod named "route-override" becomes ready

    # Check created pod has correct default route
    When I execute on the "route-override" pod:
      | ip | route |
    Then the output should contain:
      | 192.168.10.0 |

  # @author weliang@redhat.com
  # @case_id OCP-30054
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-30054:SDN Multus namespaceIsolation should allow references to CRD in the default namespace
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def in default namespace via cluster admin
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-macvlan.yaml"
    When I run oc create as admin over "whereabouts-macvlan.yaml" replacing paths:
      | ["metadata"]["namespace"] | default                                                                                                                          |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "mode": "bridge", "ipam": { "type": "whereabouts", "range": "192.168.22.100/24"} }' |
    Then the step should succeed

    #Cleanup created net-attach-def from default namespaces
    And admin ensures "macvlan-bridge-whereabouts" network_attachment_definition is deleted from the "default" project after scenario

    # Create a pod absorbing above net-attach-def defined in default namespace
    Given I have a project
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod1    |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | default/macvlan-bridge-whereabouts |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge-whereabouts         |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod1" becomes ready

  # @author weliang@redhat.com
  # @case_id OCP-29742
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-29742:SDN Log pod IP and pod UUID when pod start
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-macvlan.yaml"
    When I run oc create as admin over "whereabouts-macvlan.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                             |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan","mode": "bridge", "ipam": { "type": "whereabouts", "range": "192.168.22.100/24"} }' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-whereabouts      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge-whereabouts      |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %>         |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod1" becomes ready
    And evaluation of `pod.ip` is stored in the :pod_eth0_ip clipboard

    When I run the :get admin command with:
      | resource | pod                               |
      | n        | <%= project.name %>               |
      | o        | jsonpath={.items[*].metadata.uid} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :pod_uid clipboard

    And I execute on the "macvlan-bridge-whereabouts-pod1" pod:
      | bash | -c | ip addr show net1 |
    Then the step should succeed
    And evaluation of `@result[:response].match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)[0]` is stored in the :pod_net1_ip clipboard

    Given I use the "<%= cb.nodes[0].name %>" node
    And I run commands on the host:
      | journalctl -u crio \| grep verbose.*macvlan-bridge-whereabouts-pod1 |
    Then the step should succeed
    And the output should contain:
      | <%= project.name %>:macvlan-bridge-whereabouts-pod1:<%= cb.pod_uid %> |
      | <%= cb.pod_eth0_ip %>                                                 |
      | <%= cb.pod_net1_ip %>                                                 |

  # @author weliang@redhat.com
  # @case_id OCP-31999
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-31999:SDN Whereabouts with exclude IP address
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-excludeIP.yaml"
    When I run oc create as admin over "whereabouts-excludeIP.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeip           |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-excludeip           |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod1" becomes ready
    # Check the created pod has correct ip
    When I execute on the "macvlan-bridge-whereabouts-pod1" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.10.4 |

    # Create second pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod2 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeip           |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-excludeip           |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod2" becomes ready
    # Check the created pod has correct ip
    When I execute on the "macvlan-bridge-whereabouts-pod2" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.10.5 |

    # Create third pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-whereabouts-pod3 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-excludeip           |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-excludeip           |
    Then the step should succeed
    And the pod named "macvlan-bridge-whereabouts-pod3" status becomes :pending within 60 seconds
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod                             |
      | name     | macvlan-bridge-whereabouts-pod3 |
    Then the output should contain "Could not allocate IP in range"
    """

  # @author weliang@redhat.com
  # @case_id OCP-33579
  @admin
  @singlenode
  @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: OCP-33579:SDN Additional network IPAM should support changes in range and overlapping ranges
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def with whereabouts-shortrange
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-overlapping.yaml"
    When I run oc create as admin over "whereabouts-overlapping.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>    |
      | ["metadata"]["name"]      | whereabouts-shortrange |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | whereabouts-shortrange-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-shortrange      |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-shortrange      |
    Then the step should succeed
    And the pod named "whereabouts-shortrange-pod1" becomes ready
    # Check the created pod which has correct ip
    When I execute on the "whereabouts-shortrange-pod1" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.42.1 |

    # Create the net-attach-def with whereabouts-largerange
    When I run oc create as admin over "whereabouts-overlapping.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>    |
      | ["metadata"]["name"]      | whereabouts-largerange |
      | ["spec"]["config"]        |'{ "cniVersion": "0.3.1", "type": "macvlan","mode": "bridge", "ipam": { "type": "whereabouts", "range": "192.168.42.0/24"} }' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | whereabouts-largerange-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-largerange      |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-largerange      |
    Then the step should succeed
    And the pod named "whereabouts-largerange-pod1" becomes ready
    # Check the created pod which has correct ip
    When I execute on the "whereabouts-largerange-pod1" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.42.2 |

    # Create third and fourth pods to absorbing above two net-attach-def
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | whereabouts-shortrange-pod2 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-shortrange      |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-shortrange      |
    Then the step should succeed
    And the pod named "whereabouts-shortrange-pod2" becomes ready
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | whereabouts-largerange-pod2 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | whereabouts-largerange      |
      | ["spec"]["containers"][0]["name"]                          | whereabouts-largerange      |
    Then the step should succeed
    And the pod named "whereabouts-largerange-pod2" becomes ready

    # Check third pod which has correct ip
    When I execute on the "whereabouts-shortrange-pod2" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.42.3 |
    # Check fourth pod which has correct ip
    When I execute on the "whereabouts-largerange-pod2" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 192.168.42.4 |

  # @author weliang@redhat.com
  # @case_id OCP-41789
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-41789:SDN BZ1944678 Whereabouts IPAM CNI duplicate IP addresses assigned to pods
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/Bug-1944678.yaml"
    When I run oc create as admin over "Bug-1944678.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-pod1 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge      |
    Then the step should succeed
    And the pod named "macvlan-bridge-pod1" becomes ready
    # Check the created pod has correct ip
    When I execute on the "macvlan-bridge-pod1" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 10.199.199.100 |

    # Create second pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-pod2 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge      |
    Then the step should succeed
    And the pod named "macvlan-bridge-pod2" becomes ready
    # Check the created pod has correct ip
    When I execute on the "macvlan-bridge-pod2" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 10.199.199.101 |

    # Create third pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod.yaml"
    When I run oc create over "generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"]                                       | macvlan-bridge-pod3 |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge      |
      | ["spec"]["containers"][0]["name"]                          | macvlan-bridge      |
    Then the step should succeed
    And the pod named "macvlan-bridge-pod3" becomes ready
    # Check the created pod has correct ip
    When I execute on the "macvlan-bridge-pod3" pod:
      | bash | -c | ip -4 -brief a |
    Then the output should contain:
      | 10.199.199.102 |

  # @author weliang@redhat.com
  # @case_id OCP-46116
  @admin
  @4.12 @4.11 @4.10
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  Scenario: OCP-46116:SDN BZ1897431 CIDR support for additional network attachment with the bridge CNI plug-in
    Given the multus is enabled on the cluster
    And I store all worker nodes to the :nodes clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    #Patching rawCNIConfig config in network operator config CRD
    Given I have a project
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:    
      | {"spec": {"additionalNetworks": [{"name": "macvlan-bridge-ipam-dhcp","namespace": "<%= project.name %>","rawCNIConfig": "{ \"cniVersion\": \"0.3.1\", \"name\": \"test-network-1\", \"type\": \"bridge\", \"ipam\": { \"type\": \"static\", \"addresses\": [ { \"address\": \"191.168.1.23\" } ] } }","type":"Raw"}]}} |

    # Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |
    """

    # Check NAD is configured under project namespace
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | net-attach-def      |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | macvlan-bridge-ipam-dhcp |
    """

    # Creating pod under openshift-multus project to absorb above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/1interface-macvlan-bridge.yaml"
    When I run oc create over "1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-ipam-dhcp |
      | ["metadata"]["namespace"]                                  | <%= project.name %>      |
      | ["spec"]["nodeName"]                                       | <%= cb.nodes[0].name %>  |
      | ["metadata"]["name"]                                       | test-pod                 | 
    Then the step should succeed
    Given the pod named "test-pod" status becomes :pending
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod      |
      | name     | test-pod |
    Then the output should contain "the 'address' field is expected to be in CIDR notation"
    """

