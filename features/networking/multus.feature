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
  # @case_id OCP-21946
  @admin
  Scenario: The multus admission controller should be able to detect the syntax issue in the net-attach-def
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin and simulating syntax errors
    Given I have a project
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml" replacing paths:
      	    | ["spec"]["config"]| 'asdf' |
    Then the step should fail
    And the output should contain:
	    | admission webhook "multus-validating-config.k8s.io" denied the request|
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml" replacing paths:
            | ["metadata"]["name"] | macvlan-bridge@$ |
    Then the step should fail
    And the output should contain:
            |subdomain must consist of lower case alphanumeric characters|

  # @author anusaxen@redhat.com
  # @case_id OCP-21949
  @admin
  Scenario: The multus admission controller should be able to detect the issue in the pod template
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run the :create admin command with:
	    | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml |
    Then the step should succeed
    # Create a pod consuming net-attach-def simulating wrong syntax in name
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-bridge.yaml" replacing paths:
	    | ["metadata"]["generateName"] | macvlan-bridge-pod-$@ |
    Then the step should fail
    And the output should contain:
            | subdomain must consist of lower case alphanumeric characters |

  # @author anusaxen@redhat.com
  # @case_id OCP-21793
  @admin
  Scenario: User cannot consume the net-attach-def created in other project which is namespace isolated	
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    And an 4 character random string of type :hex is stored into the :nic_name clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    And evaluation of `node.name` is stored in the :target_node clipboard
    # Create the net-attach-def via cluster admin
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    When I run the :create client command with:
	    | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-bridge.yaml |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    When I run the :delete client command with:
            | object_type       | net-attach-def |
            | object_name_or_id | macvlan-bridge |
    Then the step should succeed
    """ 
    # Creating pod in the user's namespace which consumes the net-attach-def created in default namespace 
    Given I switch to the first user
    And I create a new project
    
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/Pods/1interface-macvlan-bridge.yaml" replacing paths:
            | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | default/macvlan-bridge-pod |
    Then the step should succeed
    And evaluation of `project.name` is stored in the :project_name clipboard
    When I run the :get client command with:
	    | resource | pod                |
	    | output   | json               |
	    | n        | <%= cb.project_name %> |
    Then the step should succeed
    And  evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :pod_name clipboard

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
	    | resource | events                 |
	    | name     | <%= cb.pod_name %>     |
       	    | n        | <%= cb.project_name %> |
    Then the step should succeed
    And the output should contain:
            | namespace isolation violation |
    """

