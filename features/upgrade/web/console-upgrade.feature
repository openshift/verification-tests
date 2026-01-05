Feature: web console related upgrade check

  # @author yanpzhan@redhat.com
  @console
  @upgrade-prepare
  @users=upuser1,upuser2
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @admin
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @hypershift-hosted
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @4.22 @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario: OCP-22597:UserInterface check console accessibility - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | ui-upgrade |
    Then the step should succeed
    Given I use the "ui-upgrade" project
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create client command with:
      | f | daemonset.yaml |
    Then the step should succeed
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    Given I obtain test data file "deployment/hello-deployment-1.yaml"
    When I run the :create client command with:
      | f | hello-deployment-1.yaml |
    Then the step should succeed
    Given I open admin console in a browser
    When I perform the :goto_deployment_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :goto_dc_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hooks |
    Then the step should succeed
    When I perform the :goto_daemonsets_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-daemonset |
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id OCP-22597
  @upgrade-check
  @admin
  @console
  @users=upuser1,upuser2
  @4.22 @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-22597:UserInterface check console accessibility
    Given the first user is cluster-admin
    Given I open admin console in a browser
    When I perform the :goto_deployment_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :goto_dc_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hooks |
    Then the step should succeed
    When I perform the :goto_daemonsets_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-daemonset |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id OCP-76051
  @upgrade-check
  @admin
  @console
  @users=upuser1,upuser2
  @4.22 @4.21 @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @vsphere-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-76051:UserInterface check vsphere connection form not empty
    Given the first user is cluster-admin
    Given I open admin console in a browser
    When I run the :goto_cluster_dashboards_page web action
    Then the step should succeed
    When I run the :check_vsphere_connection_form_not_empty web action
    Then the step should succeed
