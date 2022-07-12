Feature: IPsec upgrade scenarios

  # @author anusaxen@redhat.com
  @admin
  @upgrade-prepare
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes @network-networkpolicy @ipsec
  @upgrade
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Confirm node-node and pod-pod packets are ESP enrypted on IPsec clusters post upgrade - prepare
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    Given I switch to cluster admin pseudo user
    And the default interface on nodes is stored in the :default_interface clipboard
    When I run the :new_project client command with:
      | project_name | ipsec-upgrade |
    Then the step should succeed
    When I use the "ipsec-upgrade" project
    Given I obtain test data file "networking/list_for_pods.json"
    #Creating two test pods for pod-pod encryption check. Pods needs to be deployment/rc backed so that they can be migrate successfuly to the upgraded cluster.Creating each separat as they need to be on diff
    #nodes
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["nodeName"]           | <%= cb.workers[1].name %> |
      | ["items"][0]["spec"]["replicas"]                               | 1                         |
      | ["items"][0]["metadata"]["name"]                               | hello-pod1-rc             |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | hello-pod1                |
      | ["items"][1]["metadata"]["name"]                               | test-service1             |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-pod1 |
    And evaluation of `pod.ip_url` is stored in the :test_pod_worker1 clipboard

    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["nodeName"]                 | <%= cb.workers[0].name %>                                                                      |
      | ["items"][0]["spec"]["replicas"]                                     | 1                                                                                              |
      | ["items"][0]["metadata"]["name"]                                     | hello-pod0-rc                                                                                  |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"]       | hello-pod0                                                                                     |
      | ["items"][1]["metadata"]["name"]                                     | test-service0                                                                                  |
      | ["items"][0]["spec"]["template"]["spec"]["containers"][0]["command"] | ["bash", "-c", "for f in {0..36000}; do curl <%= cb.test_pod_worker1 %>:8080 ; sleep 1; done"] |

    Then the step should succeed
    #Above command will curl "hello openshift" traffic every 1 second to worker1 test pod which is expected to cause ESP traffic generation across those nodes
    And a pod becomes ready with labels:
      | name=hello-pod0 |
    #Quick pre-upgrade check whether nodes are getting ESP packets or not. Just to confirm IPsec functionality
    #Host network pod for running tcpdump on any  worker node to leverage tcpdump utility
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                       | <%= cb.workers[0].name %> |
      | ["metadata"]["namespace"]                                  | ipsec-upgrade             |
      | ["metadata"]["name"]                                       | hostnw-pod-worker0        |
      | ["metadata"]["labels"]["name"]                             | network-pod               |
      | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                      |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod |
    And evaluation of `pod.name` is stored in the :hostnw_pod_worker0 clipboard
    #capturing tcpdump for 2 seconds
    Given I use the "ipsec-upgrade" project
    When admin executes on the "<%= cb.hostnw_pod_worker0 %>" pod:
       | sh | -c | timeout  --preserve-status 2 tcpdump -i <%= cb.default_interface %> esp |
    Then the step should succeed
    And the output should contain "ESP"

  # @author anusaxen@redhat.com
  # @case_id OCP-44834
  @admin
  @upgrade-check
  @network-ovnkubernetes @network-networkpolicy @ipsec
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7
  @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Confirm node-node and pod-pod packets are ESP enrypted on IPsec clusters post upgrade
    Given the IPsec is enabled on the cluster
    Given evaluation of `50` is stored in the :protocol clipboard
    Given I switch to cluster admin pseudo user
    And the default interface on nodes is stored in the :default_interface clipboard
    And I use the "ipsec-upgrade" project
    And a pod becomes ready with labels:
      | name=hello-pod0 |
    And evaluation of `pod.node_name` is stored in the :worker0 clipboard
    And a pod becomes ready with labels:
      | name=hello-pod1 |
    And evaluation of `pod.node_name` is stored in the :worker1 clipboard
    And the Internal IP of node "<%= cb.worker1 %>" is stored in the :host_ip clipboard
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    #Host network pod for running tcpdump on correcpdonding worker node
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
      | ["spec"]["nodeName"]                                       | <%= cb.worker1 %>  |
      | ["metadata"]["namespace"]                                  | ipsec-upgrade      |
      | ["metadata"]["name"]                                       | hostnw-pod-worker1 |
      | ["metadata"]["labels"]["name"]                             | network-pod1       |
      | ["spec"]["containers"][0]["securityContext"]["privileged"] | true               |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod1 |
    And evaluation of `pod.name` is stored in the :hostnw_pod_worker1 clipboard
    #capturing tcpdump for 2 seconds
    When admin executes on the "<%= cb.hostnw_pod_worker1 %>" pod:
       | sh | -c | timeout  --preserve-status 2 tcpdump -i <%= cb.default_interface %> esp |
    Then the step should succeed
    #Following will confirm pod-pod encryption
    #Example ESP packet un-encrypted will look like 16:37:16.309297 IP ip-10-0-x-x.us-east-2.compute.internal > ip-10-0-x-x.us-east-2.compute.internal: ESP(spi=0xf50c771c,seq=0xfaad)
    And the output should match:
       | <%= cb.worker0 %>.* > <%= cb.worker1 %>.*: ESP |
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create as admin over "net_admin_cap_pod.yaml" replacing paths:
       | ["spec"]["nodeName"]           | <%= cb.worker0 %>  |
       | ["metadata"]["name"]           | hostnw-pod-worker0 |
       | ["metadata"]["namespace"]      | ipsec-upgrade      |
       | ["metadata"]["labels"]["name"] | network-pod0       |
    #Below socat command will send ESP traffic at a length less than 40 between worker 0 and worker1 nodes
       | ["spec"]["containers"][0]["command"]                       | ["sh", "-c", "socat /dev/random ip-sendto:<%= cb.host_ip %>:<%= cb.protocol %>"] |
       | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                                                                               |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod0 |
    #Following will confirm node-node encryption
    When admin executes on the "<%= cb.hostnw_pod_worker1 %>" pod:
       | sh | -c | timeout  --preserve-status 60 tcpdump -c 2 -i br-ex "esp and less 1500" |
    Then the step should succeed
    And the output should not contain "0 packets captured"
