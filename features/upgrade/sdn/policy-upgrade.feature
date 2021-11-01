Feature: SDN compoment upgrade testing

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario: network operator should be available after upgrade - prepare
  # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
  # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
  # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author huirwang@redhat.com
  # @case_id OCP-22707
  @admin
  @upgrade-check
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: network operator should be available after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-network-operator" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=network-operator |
    # Check network operator version match cluster version
    And the "network" operator version matches the current cluster version
    # Check the operator object has status for Degraded|Progressing|Available|Upgradeable
    And the expression should be true> cluster_operator('network').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('network').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Upgradeable')['status'] == "True"


  # @author zzhao@redhat.com
  @admin
  @upgrade-prepare
  @4.10 @4.9
  Scenario: Check the networkpolicy works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | policy-upgrade |
    Then the step should succeed
    When I use the "policy-upgrade" project
    Given I obtain test data file "networking/list_for_pods.json"
    And I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"

    Given the DefaultDeny policy is applied to the "policy-upgrade" namespace
    Then the step should succeed

    When I use the "policy-upgrade" project

    And I wait up to 10 seconds for the steps to pass:
    """
    Then I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    And the step should fail
    And the output should not contain "Hello"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-22735
  @admin
  @upgrade-check
  @4.10 @4.9
  @azure-ipi @openstack-ipi @baremetal-ipi @vsphere-ipi @gcp-ipi @aws-ipi
  @azure-upi @aws-upi @openstack-upi @vsphere-upi @gcp-upi
  Scenario: Check the networkpolicy works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "policy-upgrade" project
    Given status becomes :running of 2 pods labeled:
      | name=test-pods |
    And evaluation of `pod(1).ip` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"


  # @author asood@redhat.com
  @admin
  @upgrade-prepare
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario: Check the namespace networkpolicy for an application works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | policy-upgrade1 |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | policy-upgrade2 |
    Then the step should succeed

    When I use the "policy-upgrade1" project
    Given I obtain test data file "networking/list_for_pods.json"
    And I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).ip_url` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    Given I obtain test data file "rc/idle-rc-1.yaml"
    When I run oc create over "idle-rc-1.yaml" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-idle |
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard
    And evaluation of `pod(2).ip_url` is stored in the :pod3ip clipboard

    When I use the "policy-upgrade2" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(3).name` is stored in the :pod4 clipboard

    Given I obtain test data file "rc/idle-rc-1.yaml"
    When I run oc create over "idle-rc-1.yaml" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-idle |
    And evaluation of `pod(4).name` is stored in the :pod5 clipboard

    When I run the :label admin command with:
      | resource | namespace                |
      | name     | policy-upgrade2          |
      | key_val  | team=operations          |
    Then the step should succeed

    Given the AllowNamespaceAndPod policy is applied to the "policy-upgrade1" namespace
    Then the step should succeed

    And I wait up to 10 seconds for the steps to pass:
    """
    When I use the "policy-upgrade1" project
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"

    When I use the "policy-upgrade2" project
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.pod5 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod3ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    """

  # @author asood@redhat.com
  # @case_id OCP-38751
  @admin
  @upgrade-check
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Check the namespace networkpolicy for an application works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "policy-upgrade1" project
    Given status becomes :running of 2 pods labeled:
      | name=test-pods |
    And evaluation of `pod(1).ip_url` is stored in the :pod2ip clipboard
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    Given a pod becomes ready with labels:
      | name=hello-idle |
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard
    And evaluation of `pod(2).ip_url` is stored in the :pod3ip clipboard
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    """

    When I use the "policy-upgrade2" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(3).name` is stored in the :pod4 clipboard
    Given a pod becomes ready with labels:
      | name=hello-idle |
    And evaluation of `pod(4).name` is stored in the :pod5 clipboard
    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should succeed
    When I execute on the "<%= cb.pod5 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should fail
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod3ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    """
    #Steps to modify policy post upgrade for bug 1973679
    When I obtain test data file "networking/networkpolicy/allow-ns-and-pod.yaml"
    And I replace lines in "allow-ns-and-pod.yaml":
      | test-pods | hello-idle |
    And I run the :replace admin command with:
      | f | allow-ns-and-pod.yaml |
      | n | policy-upgrade1       |
    Then the step should succeed

    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod3ip %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.pod5 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod2ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.pod5 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.pod3ip %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    """

  # @author asood@redhat.com
  @admin
  @upgrade-prepare
  @4.10 @4.9
  Scenario: Check allow from router and allow from hostnetwork policy are functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | policy-upgrade3 |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | policy-upgrade4 |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | policy-upgrade5 |
    Then the step should succeed

    #Setup
    When I use the "policy-upgrade3" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    When I expose the "test-service" service
    And I wait up to 60 seconds for a web server to become available via the "test-service" route
    Given the DefaultDeny policy is applied to the "policy-upgrade3" namespace
    Then the step should succeed
    Given I obtain test data file "networking/networkpolicy/allow-from-router-ingress.yaml"
    When I run the :create admin command with:
      | f | allow-from-router-ingress.yaml     |
    Then the step should succeed

    When I use the "policy-upgrade4" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    When I expose the "test-service" service
    And I wait up to 60 seconds for a web server to become available via the "test-service" route
    Given the DefaultDeny policy is applied to the "policy-upgrade4" namespace
    Then the step should succeed
    Given I obtain test data file "networking/networkpolicy/allow-from-router.yaml"
    When I run the :create admin command with:
      | f | allow-from-router.yaml     |
    Then the step should succeed

    When I use the "policy-upgrade5" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"]  | 1    |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    Then the step should succeed
    And evaluation of `pod(2).ip_url` is stored in the :p5pod1ip clipboard
    Given I save multus pod on master node to the :multuspod clipboard
    Given the DefaultDeny policy is applied to the "policy-upgrade5" namespace
    Then the step should succeed
    Given I obtain test data file "networking/networkpolicy/allow-from-hostnetwork.yaml"
    When I run the :create admin command with:
      | f | allow-from-hostnetwork.yaml     |
    Then the step should succeed

    #Validation
    And I wait up to 30 seconds for the steps to pass:
    """
    When I use the "policy-upgrade3" project
    When I open web server via the "test-service" route
    Then the step should succeed

    When I use the "policy-upgrade4" project
    When I open web server via the "test-service" route
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    Given I use the "openshift-multus" project
    When I execute on the "<%= cb.multuspod %>" pod:
      | curl | -I | <%= cb.p5pod1ip %>:8080 |
    Then the step should succeed
    And the output should contain "200 OK"
    """

  # @author asood@redhat.com
  # @case_id OCP-40620
  @admin
  @upgrade-check
  @4.10 @4.9
  @azure-ipi @openstack-ipi @baremetal-ipi @vsphere-ipi @gcp-ipi @aws-ipi
  @azure-upi @aws-upi @openstack-upi @vsphere-upi @gcp-upi
  Scenario: Check allow from router and allow from hostnetwork policy are functional post upgrade
    Given I switch to cluster admin pseudo user
    When I use the "policy-upgrade3" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And I wait up to 60 seconds for a web server to become available via the "test-service" route

    When I use the "policy-upgrade4" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And I wait up to 60 seconds for a web server to become available via the "test-service" route

    When I use the "policy-upgrade5" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(2).ip_url` is stored in the :p5pod1ip clipboard
    Given I save multus pod on master node to the :multuspod clipboard
    And I wait up to 30 seconds for the steps to pass:
    """
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-multus" project
    When I execute on the "<%= cb.multuspod %>" pod:
      | curl | -I | <%= cb.p5pod1ip %>:8080 |
    Then the step should succeed
    """

  # @author anusaxen@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Conntrack rule for UDP traffic should be removed when the pod for NodePort service deleted post upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I store the workers in the :nodes clipboard
    When I run the :new_project client command with:
      | project_name | nodeport-upgrade |
    Then the step should succeed
    Given I use the "nodeport-upgrade" project
    And I obtain test data file "networking/pod_with_udp_port_4789_nodename.json"
    When I run oc create over "pod_with_udp_port_4789_nodename.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["nodeName"] | <%= cb.nodes[0].name %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=udp-pods |
    And evaluation of `pod` is stored in the :host_pod1 clipboard

    #Using node port to expose the service on port 8080 on the node IP address
    When I run the :expose client command with:
      | resource      | pod                      |
      | resource_name | <%= cb.host_pod1.name %> |
      | type          | NodePort                 |
      | port          | 8080                     |
      | protocol      | UDP                      |
    Then the step should succeed
    
  # @author anusaxen@redhat.com
  # @case_id OCP-44901
  @admin
  @upgrade-check
  Scenario: Conntrack rule for UDP traffic should be removed when the pod for NodePort service deleted post upgrade
    Given I switch to cluster admin pseudo user
    And I use the "nodeport-upgrade" project
    And a pod becomes ready with labels:
      | name=udp-pods |
    And evaluation of `pod` is stored in the :host_pod1 clipboard
    #Getting service name and nodeport value
    When I run the :get client command with:
      | resource | svc                                |
      | o        | jsonpath={.items[*].metadata.name} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :service_name clipboard
    And evaluation of `service(cb.service_name).node_port(port: 8080)` is stored in the :nodeport clipboard

    # Creating a simple client pod to generate traffic from it towards the exposed node IP address
    Given I obtain test data file "networking/aosqe-pod-for-ping.json"
    When I run oc create over "aosqe-pod-for-ping.json" replacing paths:
      | ["spec"]["nodeName"] | <%= cb.host_pod1.node_name %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=hello-pod |
    And evaluation of `pod` is stored in the :client_pod clipboard

    # The 3 seconds mechanism via for loop will create an Assured conntrack entry which will give us enough time to validate upcoming steps
    When I run the :exec background client command with:
      | pod              | <%= cb.client_pod.name %>                                                                            |
      | oc_opts_end      |                                                                                                      |
      | exec_command     | bash                                                                                                 |
      | exec_command_arg | -c                                                                                                   |
      | exec_command_arg | for n in {1..3}; do echo $n; sleep 1; done>/dev/udp/<%= cb.host_pod1.node_name %>/<%= cb.nodeport %> |
    Then the step should succeed
    
    #Creating network test pod to levearage conntrack tool
    Given I obtain test data file "networking/net_admin_cap_pod.yaml"
    When I run oc create over "net_admin_cap_pod.yaml" replacing paths:
      | ["spec"]["nodeName"] | <%= cb.host_pod1.node_name %> |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=network-pod |
    And evaluation of `pod.name` is stored in the :network_pod clipboard
    Given I wait up to 20 seconds for the steps to pass:
    """
    And I execute on the pod:
      | bash | -c | conntrack -L \| grep "<%= cb.nodeport %>" |
    Then the step should succeed
    And the output should contain:
      |<%= cb.host_pod1.ip %>|
    """
    #Deleting the udp listener pod which will trigger a new udp listener pod with new IP
    Given I ensure "<%= cb.host_pod1.name %>" pod is deleted
    And a pod becomes ready with labels:
      | name=udp-pods |
    And evaluation of `pod` is stored in the :host_pod2 clipboard

    # The 3 seconds mechanism via for loop will create an Assured conntrack entry which will give us enough time to validate upcoming steps
    When I run the :exec background client command with:
      | pod              | <%= cb.client_pod.name %>                                                                            |
      | oc_opts_end      |                                                                                                      |
      | exec_command     | bash                                                                                                 |
      | exec_command_arg | -c                                                                                                   |
      | exec_command_arg | for n in {1..3}; do echo $n; sleep 1; done>/dev/udp/<%= cb.host_pod1.node_name %>/<%= cb.nodeport %> |
    Then the step should succeed
    #Making sure that the conntrack table should not contain old deleted udp listener pod IP entries but new pod one's
    Given I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.network_pod %>" pod:
      | bash | -c | conntrack -L \| grep "<%= cb.nodeport %>" |
    Then the output should contain "<%= cb.host_pod2.ip %>"
    And the output should not contain "<%= cb.host_pod1.ip %>"
    """

