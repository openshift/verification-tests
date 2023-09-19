Feature: Storage of Hostpath plugin testing

  # @author chaoyang@redhat.com
  # @author lxia@redhat.com
  @admin
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
    @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @storage
  Scenario Outline: Create hostpath pv with access mode and reclaim policy
    Given I have a project with proper privilege
    Given I obtain test data file "storage/hostpath/local.yaml"
    When admin creates a PV from "local.yaml" where:
      | ["metadata"]["name"]                      | pv-<%= project.name %>                   |
      | ["spec"]["hostPath"]["path"]              | /etc/origin/hostpath/<%= project.name %> |
      | ["spec"]["hostPath"]["type"]              | DirectoryOrCreate                        |
      | ["spec"]["accessModes"][0]                | <access_mode>                            |
      | ["spec"]["storageClassName"]              | sc-<%= project.name %>                   |
      | ["spec"]["persistentVolumeReclaimPolicy"] | <reclaim_policy>                         |
    Then the step should succeed
    Given I obtain test data file "storage/hostpath/claim.yaml"
    When I create a dynamic pvc from "claim.yaml" replacing paths:
      | ["metadata"]["name"]         | mypvc                  |
      | ["spec"]["volumeName"]       | pv-<%= project.name %> |
      | ["spec"]["accessModes"][0]   | <access_mode>          |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> |
    Then the step should succeed
    And the "mypvc" PVC becomes bound to the "pv-<%= project.name %>" PV

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/hostpath/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
    Then the step should succeed

    Given the pod named "mypod" becomes ready
    And I use the "<%= pod.node_name %>" node
    And the "/etc/origin/hostpath/<%= project.name %>" path is recursively removed on the host after scenario
    When I execute on the pod:
      | touch | /mnt/local/test |
    Then the step should succeed

    Given I ensure "mypod" pod is deleted
    And I ensure "mypvc" pvc is deleted
    And the PV becomes :<pv_status> within 300 seconds

    When I run commands on the host:
      | ls /etc/origin/hostpath/<%= project.name %>/test |
    Then the step should <step_status>

    @rosa @osd_ccs @aro
    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @hypershift-hosted
    @critical
    Examples:
      | case_id          | access_mode   | reclaim_policy | pv_status | step_status |
      | OCP-9639:Storage | ReadWriteOnce | Retain         | released  | succeed     | # @case_id OCP-9639
