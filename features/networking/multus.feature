Feature: Multus-CNI related scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-21151
  @admin
  Scenario: Create pods with multus-cni - macvlan bridge mode
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard    
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |    
      | ["spec"]["config"]["eth0"]| <%= cb.default_interface %> |
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |      
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


  # @author bmeng@redhat.com
  # @case_id OCP-21489
  @admin
  Scenario: Create pods with multus-cni - macvlan private mode
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard    
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-private.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]["eth0"]| <%= cb.default_interface %> |
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |      
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-private.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-private-pod |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode private is added to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode private"
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
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-private.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.pod_node %>" |
    Then the step should succeed
    And 2 pods become ready with labels:
      | name=macvlan-private-pod |
    And evaluation of `pod(-1).name` is stored in the :pod2 clipboard

    # Try to access both the cluster ip and macvlan ip on pod1 from pod2
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_sdn_ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pod1_multus_ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello OpenShift"


  # @author bmeng@redhat.com
  # @case_id OCP-21496
  @admin
  Scenario: Create pods with multus-cni - macvlan vepa mode
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard    
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-vepa.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]["eth0"]| <%= cb.default_interface %> |
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |      
    Then the step should succeed

    # Create the first pod which consumes the macvlan custom resource
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-vepa.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-vepa-pod |
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard

    # Check that the macvlan with mode vepa is added to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "macvlan mode vepa"
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
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-vepa.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.pod_node %>" |
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
  Scenario: Create pods with multus-cni - host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
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
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.0", "type": "host-device", "device": "<%= cb.nic_name %>"}' |
    Then the step should succeed
    # Create the first pod which consumes the host-device custom resource
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-host-device.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=host-device-pod |
    And evaluation of `pod.name` is stored in the :hostdev_pod clipboard

    # Check that the host-device is added to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
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
  Scenario: Create pods with muliple cni plugins via multus-cni - macvlan + macvlan
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard    
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]["eth0"]| <%= cb.default_interface %> |
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |      
    Then the step should succeed

    # Create the pod which consumes multiple macvlan custom resources
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/2interface-macvlan-macvlan.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge, macvlan-bridge |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=two-macvlan-pod |

    # Check that there are two additional interfaces attached to the pod
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    Then the output should contain "net2"
    And the output should contain 2 times:
      | macvlan mode bridge |
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip -f inet addr show net1 \| grep -Po 'inet \K[\d.]+' |
    Then the output should match "10.1.1.\d{1,3}"
    And the expression should be true> IPAddr.new(@result[:response].chomp)
    And evaluation of `@result[:response].chomp` is stored in the :pod_multus_ip1 clipboard
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip -f inet addr show net2 \| grep -Po 'inet \K[\d.]+' |
    Then the output should match "10.1.1.\d{1,3}"
    And the expression should be true> IPAddr.new(@result[:response].chomp)
    And evaluation of `@result[:response].chomp` is stored in the :pod_multus_ip2 clipboard
    And the expression should be true> cb.pod_multus_ip1 != cb.pod_multus_ip2

  # @author bmeng@redhat.com
  # @case_id OCP-21855
  @admin
  @destructive
  Scenario: Create pods with muliple cni plugins via multus-cni - macvlan + host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    And an 4 character random string of type :hex is stored into the :nic_name clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]["eth0"]| <%= cb.default_interface %> |
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |      
    Then the step should succeed
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %> |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.0", "type": "host-device", "device": "<%= cb.nic_name %>"}' |
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
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/2interface-macvlan-hostdevice.yaml" replacing paths:
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
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "net2"
    And the output should contain "macvlan mode bridge"
    And the output should contain "macvlan mode private"
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip -f inet addr show net2 \| grep -Po 'inet \K[\d.]+' |
    Then the output should match "10.1.1.\d{1,3}"
    And the expression should be true> IPAddr.new(@result[:response].chomp)

  # @author bmeng@redhat.com
  # @case_id OCP-21859
  @admin
  @destructive
  Scenario: Create pods with muliple cni plugins via multus-cni - host-device + host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    And an 4 character random string of type :hex is stored into the :nic_name1 clipboard
    And an 4 character random string of type :hex is stored into the :nic_name2 clipboard

    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml" replacing paths:
      | ["metadata"]["name"]      | host-device       |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.0", "type": "host-device", "device": "<%= cb.nic_name1%>"}' |
      | ["metadata"]["namespace"] | <%= project.name %> |
    Then the step should succeed
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml" replacing paths:
      | ["metadata"]["name"]      | host-device-2       |
      | ["spec"]["config"]        | '{"cniVersion": "0.3.0", "type": "host-device", "device": "<%= cb.nic_name2%>"}' |
      | ["metadata"]["namespace"] | <%= project.name %> |
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
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/2interface-hostdevice-hostdevice.yaml" replacing paths:
      | ["spec"]["nodeName"] | "<%= cb.target_node %>" |
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
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And the output should contain "net2"
    And the output should contain 2 times:
	    | macvlan mode bridge |

  # @author anusaxen@redhat.com
  # @case_id OCP-24488
  @admin
  Scenario: Create pod with Multus bridge CNI plugin without vlan
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    And evaluation of `project.name` is stored in the :project_name clipboard
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/bridge-host-local-novlan.yaml |
      | n | <%= cb.project_name %>                                                                                                                              |
    Then the step should succeed
    #Creating no-vlan pod abosrbing above net-attach-def
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/generic_multus_pod.yaml" replacing paths:
      | ["metadata"]["name"] | pod-novlan |
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridge3    |
      | ["spec"]["containers"][0]["name"] | pod-novlan |
    Then the step should succeed
    And the pod named "pod-novlan" becomes ready
    And evaluation of `pod` is stored in the :pod clipboard
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    #Entering into corresponding no eot make sure No VLAN ID information shown for secondary interface
    Given CNI vlan info is obtained on the "<%= cb.pod.node_name %>" node
    Then the step should succeed
    And the output should contain:
      | 1 PVID untagged |

  # @author anusaxen@redhat.com
  # @case_id OCP-24489
  @admin
  Scenario: Create pod with Multus bridge CNI plugin and vlan tag
    # Make sure that the multus is enabled
    Given the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    And evaluation of `project.name` is stored in the :project_name clipboard
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/weliang1/Openshift_Networking/master/Features/multus/bridge-host-local-vlan200.yaml |
      | n | <%= cb.project_name %>                                                                                                |
    Then the step should succeed
    #Creating vlan pod abosrbing above net-attach-def
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/weliang1/Openshift_Networking/master/Features/multus/pod1-bridge-host-local-vlan200.yaml |
      | n | <%= cb.project_name %>                                                                                                     |
    Then the step should succeed
    And the pod named "pod1-vlan200" becomes ready
    And evaluation of `pod` is stored in the :pod clipboard
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
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
  Scenario: CNO manager mavlan configured manually with static
    # Make sure that the multus is Running
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard 
    #Patching simplemacvlan config in network operator config CRD
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks":[{"name":"test-macvlan-case3","namespace":"openshift-multus","simpleMacvlanConfig":{"ipamConfig":{"staticIPAMConfig":{"addresses": [{"address":"10.128.2.100/23","gateway":"10.128.2.1"}]},"type":"static"},"master":"<%= cb.default_interface %>","mode":"bridge"},"type":"SimpleMacvlan"}]}} |
    #Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with: 
    | {"spec":{"additionalNetworks": null}} |
    """
 
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | net-attach-def   |
      | n        | openshift-multus |
    Then the step should succeed
    And the output should contain:
      | test-macvlan-case3 |
    """
    #Creating pod under openshift-multus project to absorb above net-attach-def
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-multus" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-bridge.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | test-macvlan-case3 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=macvlan-bridge-pod |
    And evaluation of `pod` is stored in the :pod clipboard

    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    And admin ensures "<%= cb.pod.name %>" pod is deleted from the "openshift-multus" project after scenario
