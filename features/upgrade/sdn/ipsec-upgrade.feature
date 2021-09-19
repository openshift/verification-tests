Feature: IPsec upgrade scenarios

  # @author anusaxen@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Confirm node-node and pod-pod packets are ESP enrypted on IPsec clusters post upgrade
    Given the env is using "OVNKubernetes" networkType
    And the IPsec is enabled on the cluster
    Given I store all worker nodes to the :workers clipboard
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | ipsec-upgrade |
    Then the step should succeed
    When I use the "ipsec-upgrade" project
    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"]           | <%= cb.workers[1].name %> |
      | ["metadata"]["name"]           | pod-worker1               |
      | ["metadata"]["labels"]["name"] | hello-pod1                |
      | ["metadata"]["namespace"]      | ipsec-upgrade             |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-pod1 |
    And evaluation of `pod.ip_url` is stored in the :test_pod_worker1 clipboard

    Given I obtain test data file "networking/pod-for-ping.json"
    When I run oc create over "pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"]                 | <%= cb.workers[0].name %>                                                                      |
      | ["metadata"]["name"]                 | pod-worker0                                                                                    |
      | ["metadata"]["labels"]["name"]       | hello-pod0                                                                                     |
      | ["metadata"]["namespace"]            | ipsec-upgrade                                                                                  |
      | ["spec"]["containers"][0]["command"] | ["bash", "-c", "for f in {0..36000}; do curl <%= cb.test_pod_worker1 %>:8080 ; sleep 1; done"] |
    Then the step should succeed
    #Above command will curl "hello openshift" traffic every 1 second to worker1 test pod which is expected to cause ESP traffic generation across those nodes
    And a pod becomes ready with labels:
      | name=hello-pod0 |
    
  # @author anusaxen@redhat.com
  # @case_id OCP-44834
  @admin
  @upgrade-check
  Scenario: Confirm node-node and pod-pod packets are ESP enrypted on IPsec clusters post upgrade
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
       | bash | -c | timeout  --preserve-status 2 tcpdump -i <%= cb.default_interface %> esp |
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
       | ["spec"]["containers"][0]["command"]                       | ["bash", "-c", "socat /dev/random ip-sendto:<%= cb.host_ip %>:<%= cb.protocol %>"] |
       | ["spec"]["containers"][0]["securityContext"]["privileged"] | true                                                                               |
    Then the step should succeed
    And a pod becomes ready with labels:
       | name=network-pod0 |
    #Following will confirm node-node encryption
    When admin executes on the "<%= cb.hostnw_pod_worker1 %>" pod:
       | bash | -c | timeout  --preserve-status 60 tcpdump -c 2 -i br-ex "esp and less 40" |
    Then the step should succeed 
    And the output should not contain "0 packets captured"
