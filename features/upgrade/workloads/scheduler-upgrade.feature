Feature: scheduler with custom policy upgrade check

  # @author knarra@redhat.com
  @upgrade-prepare
  @admin
  @destructive
  @flaky
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: Upgrading cluster when using a custom policy for kube-scheduler should work fine - prepare
    Given the "kube-scheduler" operator version matches the current cluster version
    Given the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Upgradeable')['status'] == "True"
    Given I obtain test data file "scheduler/policy_upgrade.json"
    When I run the :create_configmap admin command with:
      | name      | scheduler-policy               |
      | from_file | policy.cfg=policy_upgrade.json |
      | namespace | openshift-config               |
    Then the step should succeed
    Given as admin I successfully merge patch resource "Scheduler/cluster" with:
      | {"spec":{"policy":{"name":"scheduler-policy"}}} |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    Then the expression should be true> cluster_operator("kube-scheduler").condition(cached: false, type: 'Progressing')['status'] == "True"
    """
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> cluster_operator("kube-scheduler").condition(cached: false, type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator("kube-scheduler").condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator("kube-scheduler").condition(type: 'Available')['status'] == "True"
    """
    Given I switch to cluster admin pseudo user
    When I use the "openshift-kube-scheduler" project
    And status becomes :running of 3 pods labeled:
      | app=openshift-kube-scheduler |
    Given evaluation of `@pods[0].name` is stored in the :schedulerpod clipboard
    When I run the :logs client command with:
      | resource_name | pod/<%=cb.schedulerpod %> |
      | c             | kube-scheduler            |
    And the output should contain:
      | map[CheckNodeUnschedulable:{} CheckVolumeBinding:{} GeneralPredicates:{} MatchInterPodAffinity:{} MaxAzureDiskVolumeCount:{} MaxCSIVolumeCountPred:{} MaxEBSVolumeCount:{} MaxGCEPDVolumeCount:{} NoDiskConflict:{} NoVolumeZoneConflict:{} PodToleratesNodeTaints:{}] |

  # @author knarra@redhat.com
  # @case_id OCP-34164
  @upgrade-check
  @admin
  @destructive
  @flaky
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: Upgrading cluster when using a custom policy for kube-scheduler should work fine
    Given the "kube-scheduler" operator version matches the current cluster version
    Given the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('kube-scheduler').condition(type: 'Upgradeable')['status'] == "True"
    When I run the :get admin command with:
      | resource      | scheduler |
      | resource_name | cluster   |
      | o             | yaml      |
    Then the step should succeed
    And the output should contain "scheduler-policy"
    Given I switch to cluster admin pseudo user
    When I use the "openshift-kube-scheduler" project
    And status becomes :running of 3 pods labeled:
      | app=openshift-kube-scheduler |
    Given evaluation of `@pods[0].name` is stored in the :schedulerpod clipboard
    When I run the :logs client command with:
      | resource_name | pod/<%=cb.schedulerpod %> |
      | c             | kube-scheduler            |
    And the output should contain:
      | map[CheckNodeUnschedulable:{} CheckVolumeBinding:{} GeneralPredicates:{} MatchInterPodAffinity:{} MaxAzureDiskVolumeCount:{} MaxCSIVolumeCountPred:{} MaxEBSVolumeCount:{} MaxGCEPDVolumeCount:{} NoDiskConflict:{} NoVolumeZoneConflict:{} PodToleratesNodeTaints:{}] |
