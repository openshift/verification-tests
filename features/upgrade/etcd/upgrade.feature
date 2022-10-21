Feature: basic verification for upgrade testing

  # @author geliu@redhat.com
  @upgrade-prepare
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: etcd-operator and cluster works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given I store the masters in the :masters clipboard
    When I use the "openshift-etcd" project
    And I store in the :pods clipboard the pods labeled:
      | app=etcd |
    Then the expression should be true> cb.pods.select {|p| p.ready_state_reachable?}.count == cb.masters.count
    And evaluation of `cb.pods[0].name` is stored in the :etcdpod clipboard
    When I run the :rsh client command with:
      | pod         | <%= cb.etcdpod %> |
      | command     | etcdctl           |
      | command_arg | endpoint          |
      | command_arg | health            |
    Then the output should contain:
      | is healthy: successfully committed proposal |
    #login in etcd member pod, and add data in the form of key - value
    When I run the :rsh client command with:
      | pod         | <%= cb.etcdpod %> |
      | command     | etcdctl           |
      | command_arg | put               |
      | command_arg | data-ocp26206     |
      | command_arg | value-of-OCP26206 |
    Then the output should contain:
      | OK |
    #Verify that the newly created data is successfully retrieved.
    When I run the :rsh client command with:
      | pod         | <%= cb.etcdpod %> |
      | command     | etcdctl           |
      | command_arg | get               |
      | command_arg | data-ocp26206     |
    Then the output should contain:
      | value-of-OCP26206 |
    # Make sure etcd operator is in desired state before going for upgrade.
    When I use the "openshift-etcd-operator" project
    And status becomes :running of 1 pods labeled:
      | app=etcd-operator |
    Then the expression should be true> cluster_operator("etcd").condition(cached: false, type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator("etcd").condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator("etcd").condition(type: 'Available')['status'] == "True"

  # @author geliu@redhat.com
  # @case_id OCP-22606
  @upgrade-check
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    Given I store the masters in the :masters clipboard
    When I use the "openshift-etcd" project
    And I store in the :pods clipboard the pods labeled:
      | app=etcd |
    Then the expression should be true> cb.pods.select {|p| p.ready_state_reachable?}.count == cb.masters.count
    And evaluation of `cb.pods[0].name` is stored in the :etcdpod clipboard
    When I run the :rsh client command with:
      | pod         | <%= cb.etcdpod %> |
      | command     | etcdctl           |
      | command_arg | endpoint          |
      | command_arg | health            |
    Then the output should contain:
      | is healthy: successfully committed proposal |
    #Verify the data created in the pre-upgrade stage is successfully retrieved post upgrade.
    When I run the :rsh client command with:
      | pod         | <%= cb.etcdpod %> |
      | command     | etcdctl           |
      | command_arg | get               |
      | command_arg | data-ocp26206     |
    Then the output should contain:
      | value-of-OCP26206 |
    # Make sure etcd operator is in desired state before going for upgrade.
    When I use the "openshift-etcd-operator" project
    And status becomes :running of 1 pods labeled:
      | app=etcd-operator |
    Then the expression should be true> cluster_operator("etcd").condition(cached: false, type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator("etcd").condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator("etcd").condition(type: 'Available')['status'] == "True"

  # @author knarra@redhat.com
  # @case_id OCP-22665
  @upgrade-check
  @admin
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @noproxy @connected
  @proxy @disconnected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: Check etcd image have been udpated to target release value after upgrade
    Given I switch to cluster admin pseudo user
    And I use the "openshift-etcd" project
    And a pod becomes ready with labels:
      | app=etcd,etcd=true |
    And evaluation of `pod.container_specs.first.image` is stored in the :etcd_image clipboard
    And evaluation of `cluster_version('version').image` is stored in the :payload_image clipboard
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    # get the proxy details
    When I run the :get admin command with:
      | resource | proxy                                 |
      | o        | jsonpath={.items[0].status.httpProxy} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :cluster_proxy clipboard

    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`
    And I run commands on the host:
      | export HTTP_PROXY=<%= cb.cluster_proxy %>      |
      | export HTTPS_PROXY=<%= cb.cluster_proxy %>     |
      | <%= cb.oc_adm_release_info %> --image-for=etcd |
    Then the step should succeed
    And the output should contain:
      | <%= cb.etcd_image %> |
