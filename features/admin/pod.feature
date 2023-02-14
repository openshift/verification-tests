Feature: pod related features

  # @author xiuli@redhat.com
  # @case_id OCP-15808
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  @critical
  Scenario: OCP-15808:Node Endpoints should update in time and no delay
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    When a pod becomes ready with labels:
      | name=test-pods|
    Then I wait for the "test-service" endpoint to appear up to 5 seconds

  # @author chezhang@redhat.com
  # @case_id OCP-10598
  @admin
  @destructive
  @inactive
  Scenario: OCP-10598:Workloads Existing pods will not be affected when node is unschedulable
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" status becomes :running
    And evaluation of `pod.node_name` is stored in the :pod_node clipboard
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard
    Given I obtain test data file "pods/pod-pull-by-tag.yaml"
    When I run the :create client command with:
      | f | pod-pull-by-tag.yaml |
    Then the step should succeed
    And the pod named "pod-pull-by-tag" status becomes :running
    Given node schedulable status should be restored after scenario
    When I run the :oadm_cordon_node admin command with:
      | node_name | <%= cb.pod_node %> |
    Then the step should succeed
    When I execute on the pod:
      | bash |
      | -c   |
      | curl http://<%= cb.pod_ip %>:8080 |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |

  # @author chezhang@redhat.com
  # @case_id OCP-11116
  @admin
  @destructive
  @inactive
  Scenario: OCP-11116:Workloads New pods creation will be disabled on unschedulable nodes
    Given I have a project
    Given I store the schedulable nodes in the :nodes clipboard
    Given node schedulable status should be restored after scenario
    When I run the :oadm_cordon_node admin command with:
      | node_name | noescape: <%= cb.nodes.map(&:name).join(" ") %> |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" status becomes :pending
    Then I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod             |
      | name     | hello-openshift |
    Then the output should match:
      | FailedScheduling.*(no nodes available to schedule pods\|0/[\d] nodes are available) |
    """
    When I get project events
    Then the output should match:
      | hello-openshift.*(no nodes available to schedule pods\|0/[\d] nodes are available) |

  # @author chezhang@redhat.com
  # @case_id OCP-11466
  @admin
  @destructive
  @inactive
  Scenario: OCP-11466:Workloads Recovering an unschedulable node
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    Given I store the schedulable nodes in the :nodes clipboard
    Given node schedulable status should be restored after scenario
    When I run the :oadm_cordon_node admin command with:
      | node_name | <%= cb.nodes[0].name %> |
    Then the step should succeed
    Given label "os=fedora" is added to the "<%= cb.nodes[0].name %>" node
    Given I obtain test data file "pods/pod-with-nodeselector.yaml"
    When I run the :create client command with:
      | f | pod-with-nodeselector.yaml |
    Then the step should succeed
    And the pod named "hello-pod" status becomes :pending
    When I run the :oadm_uncordon_node admin command with:
      | node_name | <%= cb.nodes[0].name %> |
    Then the step should succeed
    And the pod named "hello-pod" status becomes :running

  # @author chezhang@redhat.com
  # @case_id OCP-11752
  @admin
  @inactive
  Scenario: OCP-11752:Node Pod will not be copied to nodes which does not match it's node selector
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    Given I store the schedulable nodes in the :nodes clipboard
    Given label "daemon=yes" is added to the "<%= cb.nodes[0].name %>" node
    Given cluster role "cluster-admin" is added to the "first" user
    Given I obtain test data file "daemon/daemonset-nodeselector.yaml"
    When I run the :create client command with:
      | f | daemonset-nodeselector.yaml |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | daemonset       |
      | name     | hello-daemonset |
    Then the output should match "1 Running.*0 Waiting.*0 Succeeded.*0 Failed"
    """
    When I run the :get client command with:
      | resource | po   |
      | o        | yaml |
    Then the output should match:
      | nodeName: <%= cb.nodes[0].name %> |

  # @author chezhang@redhat.com
  # @case_id OCP-11925
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @critical
  Scenario: OCP-11925:Node Pods will still be created by DaemonSet when nodes are SchedulingDisabled
    Given I have a project
    Given I store the schedulable workers in the :nodes clipboard
    Given node schedulable status should be restored after scenario
    When I run the :oadm_cordon_node admin command with:
      | node_name | <%= cb.nodes[0].name %> |
    Then the step should succeed
    Given cluster role "cluster-admin" is added to the "first" user
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create client command with:
      | f | daemonset.yaml |
    Then the step should succeed
    Then I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | daemonset       |
      | name     | hello-daemonset |
    Then the output should match "0 Waiting.*0 Succeeded.*0 Failed"
    """
    When I run the :get client command with:
      | resource | po   |
      | o        | yaml |
    Then the output should match:
      | nodeName: <%= cb.nodes[0].name %> |

  # @author chezhang@redhat.com
  # @author weinliu@redhat.com
  # @case_id OCP-12047
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @critical
  Scenario: OCP-12047:Node When node labels change, DaemonSet will add pods to newly matching nodes and delete pods from not-matching nodes
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    Given I store the schedulable workers in the :nodes clipboard
    Given environment has at least 2 schedulable nodes
    Given label "daemon=yes" is added to the "<%= cb.nodes[0].name %>" node
    Given label "daemon=no" is added to the "<%= cb.nodes[1].name %>" node
    Given cluster role "cluster-admin" is added to the "first" user
    Given I obtain test data file "daemon/daemonset-nodeselector.yaml"
    When I run the :create client command with:
      | f | daemonset-nodeselector.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | daemonset       |
      | name     | hello-daemonset |
    Then the output should match "1 Running.*0 Waiting.*0 Succeeded.*0 Failed"
    """
    When I run the :get client command with:
      | resource | po   |
      | o        | yaml |
    Then the output should match:
      | nodeName: <%= cb.nodes[0].name %> |
    When I run the :label admin command with:
      | resource  | node                    |
      | name      | <%= cb.nodes[0].name %> |
      | key_val   | daemon=no               |
      | overwrite | true                    |
    Then the step should succeed
    When I run the :label admin command with:
      | resource  | node                    |
      | name      | <%= cb.nodes[1].name %> |
      | key_val   | daemon=yes              |
      | overwrite | true                    |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | po   |
      | o        | yaml |
    Then the output should match:
      | nodeName: <%= cb.nodes[1].name %> |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-12338
  @admin
  @destructive
  @inactive
  Scenario: OCP-12338:Node Secret is valid after node reboot
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    Given SCC "privileged" is added to the "default" user
    Given I store the schedulable nodes in the :nodes clipboard
    Given I obtain test data file "secrets/ocp12338/secret-nginx-2.yaml"
    When I run the :create client command with:
      | f | secret-nginx-2.yaml |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | secret         |
      | resource_name | secret-nginx-2 |
    Then the output should match:
      | secret-nginx-2\\s+Opaque\\s+2  |
    When I run the :describe client command with:
      | resource | secret         |
      | name     | secret-nginx-2 |
    Then the output should match:
      | password:\\s+11 bytes |
      | username:\\s+9 bytes  |
    Given I obtain test data file "secrets/ocp12338/secret-pod-nginx-2.yaml"
    When I run oc create over "secret-pod-nginx-2.yaml" replacing paths:
      | ["spec"]["nodeName"] | <%= cb.nodes[0].name %> |
    And the step should succeed
    Given the pod named "secret-pod-nginx-2" becomes ready
    When I execute on the pod:
      | cat | /etc/secret-volume-2/password | /etc/secret-volume-2/username |
    Then the step should succeed
    And the output by order should match:
      | value-2 |
      | value-1 |
    When I run the :patch client command with:
      | resource      | secret                                                                   |
      | resource_name | secret-nginx-2                                                           |
      | p             | { "data": { "password": null, "username": "dXNlcm5hbWVjaGFuZ2VkCg==" } } |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | secret         |
      | resource_name | secret-nginx-2 |
    Then the output should match:
      | secret-nginx-2\\s+Opaque\\s+1  |
    When I run the :describe client command with:
      | resource | secret         |
      | name     | secret-nginx-2 |
    Then the output should match:
      | username:\\s+16 bytes |
    When I execute on the pod:
      | cat | /etc/secret-volume-2/password | /etc/secret-volume-2/username |
    Then the step should succeed
    And the output by order should match:
      | value-2 |
      | value-1 |
    Given I use the "<%= cb.nodes[0].name %>" node
    And the host is rebooted and I wait it up to 600 seconds to become available
    And I wait up to 500 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /etc/secret-volume-2/username |
    Then the step should succeed
    And the output should match:
      | usernamechanged |
    """
