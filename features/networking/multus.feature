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


  # @author bmeng@redhat.com
  # @case_id OCP-21489
  @admin
  Scenario: Create pods with multus-cni - macvlan private mode
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster

    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-private.yaml |
      | n | <%= project.name %> |
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

    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/macvlan-vepa.yaml |
      | n | <%= project.name %> |
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
  Scenario: Create pods with multus-cni - host-device
    # Make sure that the multus is enabled
    Given the master version >= "4.0"
    And the multus is enabled on the cluster
    And I select a random node's host
    And evaluation of `node.name` is stored in the :target_node clipboard

    # Add a host-device which will be used by the pod later
    Given I run the :get admin command with:
      | resource      | pod                                 |
      | n             | openshift-sdn                       |
      | fieldSelector | spec.nodeName=<%= cb.target_node %> |
      | l             | app=sdn                             |
      | o             | jsonpath={.items[0].metadata.name}  |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :target_sdnpod clipboard

    Given I run the :exec admin command with:
      | pod              | <%= cb.target_sdnpod %>                              |
      | n                | openshift-sdn                                        |
      | oc_opts_end      |                                                      |
      | exec_command     | sh                                                   |
      | exec_command_arg | -c                                                   |
      | exec_command_arg | ip link add eth08 link eth0 type macvlan mode bridge |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run the :exec admin command with:
      | pod              | <%= cb.target_sdnpod %> |
      | n                | openshift-sdn           |
      | oc_opts_end      |                         |
      | exec_command     | sh                      |
      | exec_command_arg | -c                      |
      | exec_command_arg | ip link del eth08       |
    the step should succeed
    """

    # Create the net-attach-def via cluster admin
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/multus-cni/NetworkAttachmentDefinitions/host-device.yaml |
      | n | <%= project.name %> |
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
    Given I run the :exec admin command with:
      | pod              | <%= cb.target_sdnpod %> |
      | n                | openshift-sdn           |
      | oc_opts_end      |                         |
      | exec_command     | sh                      |
      | exec_command_arg | -c                      |
      | exec_command_arg | ip link show            |
    Then the step should succeed
    And the output should not contain "eth08"

    # Delete the pod and check the link on the node again
    When I run the :delete client command with:
      | object_type | pod                  |
      | l           | name=host-device-pod |
    Then the step should succeed
    Given I run the :exec admin command with:
      | pod              | <%= cb.target_sdnpod %> |
      | n                | openshift-sdn           |
      | oc_opts_end      |                         |
      | exec_command     | sh                      |
      | exec_command_arg | -c                      |
      | exec_command_arg | ip link show            |
    Then the step should succeed
    And the output should contain "eth08"
