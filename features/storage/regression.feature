Feature: Regression testing cases

  # @author jhou@redhat.com
  # @case_id OCP-16485
  @admin
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @rosa @osd_ccs @aro
  @vsphere-ipi @openstack-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  @storage
  Scenario: OCP-16485:Storage RWO volumes are exclusively mounted on different nodes
    Given I have a project
    Given I store the schedulable workers in the :workers clipboard

    Given I obtain test data file "storage/misc/pvc.json"
    Given I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | ds            |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi           |

    Given I obtain test data file "storage/misc/damonset.json"
    When I run the :create admin command with:
      | f | damonset.json       |
      | n | <%= project.name %> |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | daemonset |
      | resource_name | dpod      |
      | o             | yaml      |
    Then the step should succeed
    And the expression should be true> @result[:parsed]['status']['numberAvailable'].to_i == 1
    And the expression should be true> @result[:parsed]['status']['numberUnavailable'].to_i == (cb.workers.length - 1)
    """
