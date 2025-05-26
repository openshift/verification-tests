Feature: basic verification for upgrade testing

  # @author geliu@redhat.com
  @upgrade-prepare
  @admin
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @ppc64le @heterogeneous @arm64 @amd64
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario: OCP-22606:Etcd etcd-operator and cluster works well after upgrade - prepare
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @connected
  @upgrade
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @ppc64le @heterogeneous @arm64 @amd64
  Scenario: OCP-22606:Etcd etcd-operator and cluster works well after upgrade
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

