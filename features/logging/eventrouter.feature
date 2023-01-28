@clusterlogging
@commonlogging
Feature: eventrouter related test

  # @author qitang@redhat.com
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.6
  Scenario Outline: The Openshift Events be parsed
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Then I run the :new_app client command with:
      | app_repo | httpd-example |
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    Given logging eventrouter is installed in the cluster
    Given a pod becomes ready with labels:
      | component=eventrouter |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>   |
      | namespace     | openshift-logging |
      | since         | 5m                |
    Then the step should succeed
    And the output should contain:
      | "verb":  |
      | "event": |
      | "reason" |
    Given I wait for the "<index_name>" index to appear in the ES pod with labels "es-node-master=true"
    And I wait up to 300 seconds for the steps to pass:
    """
    And I perform the HTTP request on the ES pod with labels "es-node-master=true":
      | relative_url | <index_name>*/_search?pretty' -d '{"_source":["kubernetes.event.*"],"sort": [{"@timestamp": {"order":"desc"}}],"query":{"term":{"kubernetes.container_name":"eventrouter"}}} |
      | op           | GET                                                                                                                                                                          |
    Then the step should succeed
    And the output should contain:
      | "event" :          |
      | "reason" :         |
      | "verb" :           |
      | "involvedObject" : |
    """

    @singlenode
    @proxy @noproxy @connected
    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @network-ovnkubernetes @network-openshiftsdn
    @hypershift-hosted
    @logging5.6 @logging5.7
    Examples:
    | case_id           | index_name  |
    | OCP-29738:Logging | infra       | # @case_id OCP-29738
