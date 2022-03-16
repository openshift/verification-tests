Feature: basic verification for upgrade testing
  # @author geliu@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  Scenario: etcd-operator and cluster works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    Given I obtain test data file "admin/subscription.yaml"
    When I run the :create client command with:
      | f | subscription.yaml |
    Then the step should succeed
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |
    When I use the "default" project
    Given I obtain test data file "admin/etcd-cluster.yaml"
    When I run the :create client command with:
      | f | etcd-cluster.yaml |
    Then the step should succeed
    #bugzilla - id=1979550
    #Then status becomes :running of exactly 3 pods labeled:
    #  | etcd_cluster=example |
    When I run the :get admin command with:
      | resource | EtcdCluster |
    Then the step should succeed
    And the output should match:
      | example.* |

  # @author geliu@redhat.com
  # @case_id OCP-22606
  @upgrade-check
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @disconnected @connected
  Scenario: etcd-operator and cluster works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "openshift-operators" project
    Then status becomes :running of exactly 1 pods labeled:
      | name=etcd-operator-alm-owned |

  # @author knarra@redhat.com
  # @case_id OCP-22665
  @upgrade-check
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @noproxy @connected
  Scenario: Check etcd image have been udpated to target release value after upgrade
    # operands
    Given I switch to cluster admin pseudo user
    And I use the "openshift-etcd" project
    And a pod becomes ready with labels:
      | app=etcd,etcd=true |
    And evaluation of `pod.container_specs.first.image` is stored in the :etcd_image clipboard
    And evaluation of `cluster_version('version').image` is stored in the :payload_image clipboard
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`
    And I run commands on the host:
      | <%= cb.oc_adm_release_info %> --image-for=etcd |
    Then the step should succeed
    And the output should contain:
      | <%= cb.etcd_image %> |
