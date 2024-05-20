Feature: OVNKubernetes IPsec related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-38846
  @admin
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-38846:SDN Should be able to send node to node ESP traffic on IPsec clusters
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    #Consider worker1 as a host where worker0 would like to send ESP traffic
    And the Internal IP of node "<%= cb.workers[1].name %>" is stored in the :host_ip clipboard
    #Using socat tool to send ESP packets to host worker1 from worker0. Port 50 is for ESP protocol. Simulating a hostnetwork pod on worker0 with privileged mode to allow socat tool leverage
    Given evaluation of `50` is stored in the :protocol clipboard
    Given I have a project
    And the appropriate pod security labels are applied to the namespace
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
       | ["spec"]["nodeName"]                                       | <%= cb.workers[0].name %>                                                          |
       | ["metadata"]["name"]                                       | hostnw-pod-worker0                                                                 |
       | ["metadata"]["namespace"]                                  | <%= project.name %>                                                                |
    #Below socat command will send ESP traffic at a length less than 40
       | ["spec"]["containers"][0]["command"]                       | ["bash", "-c", "socat /dev/random ip-sendto:<%= cb.host_ip %>:<%= cb.protocol %>"] |
       | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                                                                               |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod |
    #Hostnetwork pod for worker1 to leverage tcpdump tool. Has to be run in privileged mode
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
       | ["spec"]["nodeName"]                                       | <%= cb.workers[1].name %> |
       | ["metadata"]["namespace"]                                  | <%= project.name %>       |
       | ["metadata"]["name"]                                       | hostnw-pod-worker1        |
       | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                      |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod |
    And evaluation of `pod.name` is stored in the :hello_pod_worker1 clipboard
    #Make sure you got some packets captured at the receiver node.The socat we used earlier will dump any ESP packets less that 40 in length (these are invalid in our clusters). Checking limited number
    #of packets say 1 or 2 should suffice as that would imply the successful communication of ESP traffic across the nodes
    When admin executes on the "<%= cb.hello_pod_worker1 %>" pod:
       | bash | -c | timeout  --preserve-status 60 tcpdump -c 2 -i br-ex "esp and less 1500" |
    Then the step should succeed
    And the output should not contain "0 packets captured"

  # @author anusaxen@redhat.com
  # @case_id OCP-38845
  @admin
  @destructive
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-38845:SDN Segfault on pluto IKE daemon should result in restarting pluto daemon and corresponding ovn-ipsec pod
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    #Getting ovn-ipsec pod name for a corresponding worker node in sight
    When I run the :get admin command with:
      | resource      | pod                                     |
      | l             | app=ovn-ipsec                           |
      | fieldSelector | spec.nodeName=<%= cb.workers[0].name %> |
      | n             | openshift-ovn-kubernetes                |
      | o             | jsonpath={.items[*].metadata.name}      |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :ovn_ipsec_pod clipboard
    Given I use the "<%= cb.workers[0].name %>" node
    #Simulating segfault on pluto IKE dameon
    And I run commands on the host:
      | pkill -SEGV pluto|
    Then the step should succeed
    #Need to give it some hard coded time for ovn-ipsec pod to notice segfault
    Given 90 seconds have passed
    #Checking readiness probe functionality to make sure it re-creates corresponding ovn-ipsec pod
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 300 seconds

  # @author anusaxen@redhat.com
  # @case_id OCP-37591
  @admin
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-37591:SDN Make sure IPsec SA's are establishing in a transport mode
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I select a random node's host
    And I run commands on the host:
      | ip x s \| grep -i "mode transport" |
    Then the step should succeed
    #We need to make sure some mode is chosen and supported only for now is transport
    And the output should contain "mode transport"

  # @author anusaxen@redhat.com
  # @case_id OCP-39216
  @admin
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-39216:SDN Pod created on IPsec cluster should have appropriate MTU size to accomdate IPsec Header
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    And the node's MTU value is stored in the :cluster_mtu clipboard
    Given I have a project
    And I have a pod-for-ping in the project
    When I execute on the pod:
      | bash | -c | cat /sys/class/net/eth0/mtu |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :test_pod_mtu clipboard
    # OVN needs 100 byte header and IPsec needs another 46 bytes due to ESP etc so the pod's mtu must be 146 bytes less than cluster mtu
    And the expression should be true> cb.test_pod_mtu.to_i + 146 == cb.cluster_mtu.to_i

  # @author anusaxen@redhat.com
  # @case_id OCP-37590
  @admin
  @destructive
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-37590:SDN Delete all ovn-ipsec containers and check if they gets recreated
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    When I run the :delete admin command with:
      | object_type | pod                      |
      | l           | app=ovn-ipsec            |
      | n           | openshift-ovn-kubernetes |
    Then the step should succeed
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 300 seconds

  # @author anusaxen@redhat.com
  # @case_id OCP-37392
  @admin
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @network-ovnkubernetes @ipsec
  @vsphere-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-37392:SDN pod to pod traffic on different nodes should be ESP encrypted
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    Given I have a project
    And the appropriate pod security labels are applied to the namespace
    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"] | <%= cb.workers[1].name %> |
      | ["metadata"]["name"] | pod-worker1               |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=hello-pod |
    And evaluation of `pod.ip_url` is stored in the :test_pod_worker1 clipboard

    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"]                 | <%= cb.workers[0].name %>                                                                     |
      | ["metadata"]["name"]                 | pod-worker0                                                                                   |
      | ["spec"]["containers"][0]["command"] | ["bash", "-c", "for f in {0..3600}; do curl <%= cb.test_pod_worker1 %>:8080 ; sleep 1; done"] |
    Then the step should succeed
    #Above command will curl "hello openshift" traffic every 1 second to worker1 test pod which is expected to cause ESP traffic generation across those nodes
    And a pod becomes ready with labels:
       | name=hello-pod |
    #Make sure you are receiving ESP packets at the destination node. For that we will simulate a prviledged pod to allow tcpdumping
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
       | ["spec"]["nodeName"]                                       | <%= cb.workers[1].name %> |
       | ["metadata"]["namespace"]                                  | <%= project.name %>       |
       | ["metadata"]["name"]                                       | hostnw-pod-worker1        |
       | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                      |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod |
    And evaluation of `pod.name` is stored in the :hostnw_pod_worker1 clipboard
    #capturing tcpdump for 2 seconds
    When admin executes on the "<%= cb.hostnw_pod_worker1 %>" pod:
       | bash | -c | timeout  --preserve-status 2 tcpdump -i <%= cb.default_interface %> esp |
    Then the step should succeed
    # Example ESP packet un-encrypted will look like 16:37:16.309297 IP ip-10-0-x-x.us-east-2.compute.internal > ip-10-0-x-x.us-east-2.compute.internal: ESP(spi=0xf50c771c,seq=0xfaad)
    And the output should match:
       | <%= cb.workers[0].name %>.* > <%= cb.workers[1].name %>.*: ESP |

  # @author weliang@redhat.com
  # @case_id OCP-40569
  @admin
  @destructive
  @network-ovnkubernetes @network-openshiftsdn
  @4.14 @4.13 @4.12 @4.11
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @singlenode
  @hypershift-hosted
  Scenario: OCP-40569:SDN Allow enablement/disablement ipsec at runtime
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is disabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    Given the default interface on nodes is stored in the :default_interface clipboard
    #Enable ipsec through CNO
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"ipsecConfig":{}}}}} |
    #Wait for network operator back to function after patching
    Given I wait up to 120 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :True
    """
    Given I wait up to 360 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :False
    """

    Given I have a project with proper privilege
    And evaluation of `project.name` is stored in the :hello_pod_project clipboard
    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"] | <%= cb.workers[1].name %> |
      | ["metadata"]["name"] | pod-worker1               |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod.ip_url` is stored in the :test_pod_worker1 clipboard

    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"]                 | <%= cb.workers[0].name %>                                                                                          |
      | ["metadata"]["name"]                 | pod-worker0                                                                                                        |
      | ["spec"]["containers"][0]["command"] | ["bash", "-c", "for f in {0..3600}; do curl <%= cb.test_pod_worker1 %>:8080 ; --connect-timeout 5; sleep 1; done"] |
    Then the step should succeed
    #Above command will curl "hello openshift" traffic every 1 second to worker1 test pod which is expected to cause ESP traffic generation across those nodes
    And a pod becomes ready with labels:
      | name=hello-pod |

    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                       | <%= cb.workers[1].name %>   |
      | ["metadata"]["namespace"]                                  | <%= cb.hello_pod_project %> |
      | ["metadata"]["name"]                                       | hostnw-pod-worker1          |
      | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                        |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=network-pod |
    And evaluation of `pod.name` is stored in the :hello_pod_worker1 clipboard

    #Check ESP traffic between two pods crossing nodes after enabling IPsec
    Given I wait up to 90 seconds for the steps to pass:
    """
    When admin executes on the "<%= cb.hello_pod_worker1 %>" pod:
      | bash | -c | timeout  --preserve-status 2 tcpdump -v -i <%= cb.default_interface %> esp |
    Then the step should succeed
    And the output should contain "ESP"
    """
    
    # Disable ipsec through CNO
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"ipsecConfig":null}}}} |
    #Wait for below operators back to function after patching
    Given I wait up to 120 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :True
    """
    Given I wait up to 360 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :False
    """
    Given I wait up to 300 seconds for the steps to pass:
    """
    Given the status of condition "Available" for "openshift-apiserver" operator is: True
    """
    Given I wait up to 300 seconds for the steps to pass:
    """
    Given the status of condition "Available" for "authentication" operator is: True
    """

    Given I switch to the first user
    And I use the "<%= cb.hello_pod_project %>" project
    
    #Check ESP traffic between two pods crossing nodes after enabling IPsec
    Given I wait up to 180 seconds for the steps to pass:
    """
    When admin executes on the "<%= cb.hello_pod_worker1 %>" pod:
      | bash | -c | timeout  --preserve-status 2 tcpdump -v -i <%= cb.default_interface %> esp |
    Then the step should succeed
    And the output should not contain "ESP"
    """
